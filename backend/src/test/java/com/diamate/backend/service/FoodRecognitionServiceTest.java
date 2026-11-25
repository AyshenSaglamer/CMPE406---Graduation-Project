package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.zip.CRC32;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import com.diamate.backend.ai.FastApiFoodResult;
import com.diamate.backend.ai.FoodVisionClient;
import com.diamate.backend.api.dto.request.FoodNutritionRequest;
import com.diamate.backend.api.dto.response.FoodNutritionResponse;
import com.diamate.backend.api.dto.response.FoodRecognitionResponse;
import com.diamate.backend.api.dto.response.FoodSearchResult;
import com.diamate.backend.entity.FoodCatalogItem;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.repository.FoodCatalogRepository;

/** Food recognition: the checks of the photo (ImageFile) and how the model's guesses are turned into the answer. */
class FoodRecognitionServiceTest {

    private static final FoodCatalogItem PIZZA = new FoodCatalogItem(76, "pizza", "Pizza", new BigDecimal("266.0"),
            new BigDecimal("33.0"), new BigDecimal("200.0"), false);
    private static final FoodCatalogItem LAHMACUN = new FoodCatalogItem(130, "lahmacun", "Lahmacun", null, null, null,
            false);

    private final FoodVisionClient client = mock(FoodVisionClient.class);
    private final FoodCatalogRepository catalog = mock(FoodCatalogRepository.class);
    private final FoodRecognitionService service = new FoodRecognitionService(client, catalog);

    // ---------- answer ----------

    @Test
    void guessesGetTheCatalogNamesAndApproximateNutrition() throws IOException {
        modelSays(guess("pizza", 0.91), guess("lahmacun", 0.06), guess("garlic_bread", 0.01));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of(PIZZA, LAHMACUN));

        FoodRecognitionResponse answer = service.recognize(photo("png"));

        assertThat(answer.model()).isEqualTo("ResNet50");
        assertThat(answer.requiresConfirmation()).isTrue();
        assertThat(answer.lowConfidence()).isFalse();
        assertThat(answer.note()).contains("Do not use these values to calculate an insulin dose");
        assertThat(answer.predictions()).hasSize(3);

        FoodRecognitionResponse.Prediction pizza = answer.predictions().get(0);
        assertThat(pizza.food()).isEqualTo("pizza");
        assertThat(pizza.displayName()).isEqualTo("Pizza");
        assertThat(pizza.confidence()).isEqualTo(0.91);
        assertThat(pizza.foodCatalogId()).isEqualTo(76L);
        assertThat(pizza.carbsGPer100g()).isEqualByComparingTo("33.0");
        assertThat(pizza.typicalServingG()).isEqualByComparingTo("200.0");
        assertThat(pizza.carbsGPerServing()).isEqualByComparingTo("66.0");
        assertThat(pizza.kcalPer100g()).isEqualByComparingTo("266.0");
        assertThat(pizza.nutritionVerified()).isFalse();

        // In the catalog without nutrition (V9): the name, no numbers.
        FoodRecognitionResponse.Prediction lahmacun = answer.predictions().get(1);
        assertThat(lahmacun.displayName()).isEqualTo("Lahmacun");
        assertThat(lahmacun.foodCatalogId()).isEqualTo(130L);
        assertThat(lahmacun.carbsGPer100g()).isNull();
        assertThat(lahmacun.carbsGPerServing()).isNull();

        // Not in the catalog at all: a readable name from the class name.
        FoodRecognitionResponse.Prediction bread = answer.predictions().get(2);
        assertThat(bread.displayName()).isEqualTo("Garlic bread");
        assertThat(bread.foodCatalogId()).isNull();
        assertThat(bread.carbsGPerServing()).isNull();
    }

    @Test
    void atMostThreeGuessesBestFirst() throws IOException {
        modelSays(guess("sushi", 0.1), guess("pizza", 0.4), guess("ramen", 0.2), guess("lokum", 0.3));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of());

        FoodRecognitionResponse answer = service.recognize(photo("jpg"));

        assertThat(answer.predictions()).extracting(FoodRecognitionResponse.Prediction::food)
                .containsExactly("pizza", "lokum", "ramen");
    }

    @Test
    void aBestGuessBelowHalfIsLowConfidence() throws IOException {
        modelSays(guess("pizza", 0.49), guess("lahmacun", 0.3));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of());

        assertThat(service.recognize(photo("png")).lowConfidence()).isTrue();
    }

    // ---------- the photo ----------

    @Test
    void theTypeComesFromTheContentAndTheServiceGetsAFixedName() throws IOException {
        modelSays(guess("pizza", 0.9));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of());
        // A JPEG named .png and declared as octet-stream (phones do that) is sent as meal.jpg / image/jpeg.
        byte[] jpeg = imageBytes("jpg", 20, 10);
        service.recognize(new MockMultipartFile("image", "../../etc/passwd.png", "application/octet-stream", jpeg));

        verify(client).predict(eq(jpeg), eq("meal.jpg"), eq(MediaType.IMAGE_JPEG));
    }

    @Test
    void webpIsAccepted() {
        modelSays(guess("pizza", 0.9));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of());
        byte[] webp = new byte[64];
        System.arraycopy("RIFF".getBytes(StandardCharsets.US_ASCII), 0, webp, 0, 4);
        System.arraycopy("WEBPVP8 ".getBytes(StandardCharsets.US_ASCII), 0, webp, 8, 8);

        service.recognize(new MockMultipartFile("image", "m.webp", "image/webp", webp));

        verify(client).predict(any(), eq("meal.webp"), eq(MediaType.parseMediaType("image/webp")));
    }

    @Test
    void wrongFilesAre400NamingTheImageField() throws IOException {
        byte[] pdf = "%PDF-1.7 not an image".getBytes(StandardCharsets.US_ASCII);
        byte[] gif = imageBytes("gif", 10, 10);
        byte[] text = "a text file renamed to .jpg".getBytes(StandardCharsets.US_ASCII);
        byte[] riffNotWebp = Arrays.copyOf("RIFF....WAVEfmt ".getBytes(StandardCharsets.US_ASCII), 32);
        for (byte[] bad : List.of(pdf, gif, text, riffNotWebp)) {
            assertRefused(new MockMultipartFile("image", "meal.jpg", "image/jpeg", bad),
                    "The image must be a JPG, PNG or WEBP file");
        }
        assertRefused(new MockMultipartFile("image", "meal.jpg", "image/jpeg", new byte[0]), "An image is required");
        assertRefused(null, "An image is required");
        verifyNoInteractions(client);
    }

    @Test
    void moreThan5MbIsRefused() {
        byte[] big = new byte[(int) ImageFile.MAX_BYTES + 1];
        big[0] = (byte) 0xFF;
        big[1] = (byte) 0xD8;
        big[2] = (byte) 0xFF;

        assertRefused(new MockMultipartFile("image", "meal.jpg", "image/jpeg", big), "The image must be at most 5 MB");
        verifyNoInteractions(client);
    }

    @Test
    void aSmallFileDeclaringAHugePictureIsRefusedWithoutDecodingIt() {
        // A PNG header that says 10 000 x 10 000 (100 MP) with no pixel data: the "decompression bomb" shape.
        assertRefused(new MockMultipartFile("image", "meal.png", "image/png", pngHeader(10_000, 10_000)),
                "The image must be at most 50 megapixels");
        verifyNoInteractions(client);
    }

    @Test
    void aCutHeaderIsRefused() throws IOException {
        byte[] cut = Arrays.copyOf(imageBytes("jpg", 20, 10), 6);
        assertRefused(new MockMultipartFile("image", "meal.jpg", "image/jpeg", cut), "The image could not be read");
        assertRefused(new MockMultipartFile("image", "meal.png", "image/png", Arrays.copyOf(pngHeader(10, 10), 12)),
                "The image could not be read");
        verifyNoInteractions(client);
    }

    // ---------- several foods, portions ----------

    private static final FoodCatalogItem HAMBURGER = new FoodCatalogItem(50, "hamburger", "Hamburger",
            new BigDecimal("250"), new BigDecimal("24"), new BigDecimal("13"), new BigDecimal("11.4"),
            new BigDecimal("200"), false);

    @Test
    void eachFoodRegionGetsItsOwnGuessesAndNutrition() throws IOException {
        when(client.predict(any(), any(), any())).thenReturn(new FastApiFoodResult(true, "ResNet50",
                List.of(guess("pizza", 0.52), guess("hamburger", 0.3)),
                List.of(new FastApiFoodResult.Item(List.of(0.05, 0.17, 0.27, 0.81), "sandwich",
                                List.of(guess("hamburger", 0.99), guess("pizza", 0.01))),
                        new FastApiFoodResult.Item(List.of(0.36, 0.16, 0.65, 0.76), "pizza",
                                List.of(guess("lahmacun", 0.4), guess("pizza", 0.35))))));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of(PIZZA, HAMBURGER, LAHMACUN));

        FoodRecognitionResponse answer = service.recognize(photo("jpg"));

        assertThat(answer.multipleFoods()).isTrue();
        assertThat(answer.items()).hasSize(2);
        FoodRecognitionResponse.DetectedFood burger = answer.items().get(0);
        assertThat(burger.box()).containsExactly(0.05, 0.17, 0.27, 0.81);
        assertThat(burger.lowConfidence()).isFalse();
        assertThat(burger.predictions().getFirst().displayName()).isEqualTo("Hamburger");
        assertThat(burger.predictions().getFirst().carbsGPerServing()).isEqualByComparingTo("48.0");
        assertThat(answer.items().get(1).lowConfidence()).isTrue();
        // One catalog query for every food in the answer.
        verify(catalog).findByNameIn(anyCollection());
    }

    @Test
    void oneRegionIsNotSeveralFoods() throws IOException {
        when(client.predict(any(), any(), any())).thenReturn(new FastApiFoodResult(true, "ResNet50",
                List.of(guess("pizza", 0.9)),
                List.of(new FastApiFoodResult.Item(List.of(0.1, 0.1, 0.9, 0.9), "pizza", List.of(guess("pizza", 0.9))))));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of(PIZZA));

        FoodRecognitionResponse answer = service.recognize(photo("jpg"));

        assertThat(answer.multipleFoods()).isFalse();
        assertThat(answer.items()).hasSize(1);
    }

    @Test
    void anOlderServiceWithoutItemsGivesNoItems() throws IOException {
        modelSays(guess("pizza", 0.9));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of(PIZZA));

        FoodRecognitionResponse answer = service.recognize(photo("jpg"));

        assertThat(answer.items()).isEmpty();
        assertThat(answer.multipleFoods()).isFalse();
    }

    @Test
    void portionOptionsAreHalfOneAndOneAndAHalfServings() throws IOException {
        modelSays(guess("hamburger", 0.9));
        when(catalog.findByNameIn(anyCollection())).thenReturn(List.of(HAMBURGER));

        FoodRecognitionResponse.Prediction burger = service.recognize(photo("jpg")).predictions().getFirst();

        assertThat(burger.kcalPerServing()).isEqualByComparingTo("500.0");
        assertThat(burger.proteinGPerServing()).isEqualByComparingTo("26.0");
        assertThat(burger.fatGPerServing()).isEqualByComparingTo("22.8");
        assertThat(burger.portionOptions()).extracting(FoodRecognitionResponse.PortionOption::size)
                .containsExactly("SMALL", "MEDIUM", "LARGE");
        assertThat(burger.portionOptions()).extracting(p -> p.grams().toPlainString())
                .containsExactly("100.0", "200.0", "300.0");
        assertThat(burger.portionOptions()).extracting(p -> p.carbsG().toPlainString())
                .containsExactly("24.0", "48.0", "72.0");
    }

    @Test
    void noPortionOptionsWithoutNutrition() {
        assertThat(FoodRecognitionService.portionOptions(LAHMACUN)).isEmpty();
    }

    // ---------- nutrition of the confirmed foods ----------

    @Test
    void nutritionOfEachFoodAndTheMeal() {
        when(catalog.findAllById(anyCollection())).thenReturn(List.of(HAMBURGER, PIZZA));

        FoodNutritionResponse answer = service.nutrition(new FoodNutritionRequest(List.of(
                new FoodNutritionRequest.Item(50L, new BigDecimal("150")),
                new FoodNutritionRequest.Item(50L, new BigDecimal("50")))));

        assertThat(answer.items()).hasSize(2);
        assertThat(answer.items().getFirst().carbsG()).isEqualByComparingTo("36.0");
        assertThat(answer.items().getFirst().kcal()).isEqualByComparingTo("375.0");
        assertThat(answer.totals().grams()).isEqualByComparingTo("200");
        assertThat(answer.totals().carbsG()).isEqualByComparingTo("48.0");
        assertThat(answer.totals().proteinG()).isEqualByComparingTo("26.0");
        assertThat(answer.totals().complete()).isTrue();
        assertThat(answer.totals().verified()).isFalse();
        assertThat(answer.note()).contains("insulin");
    }

    @Test
    void aFoodWithoutValuesMakesTheTotalsIncompleteNotZero() {
        when(catalog.findAllById(anyCollection())).thenReturn(List.of(HAMBURGER, LAHMACUN));

        FoodNutritionResponse answer = service.nutrition(new FoodNutritionRequest(List.of(
                new FoodNutritionRequest.Item(50L, new BigDecimal("200")),
                new FoodNutritionRequest.Item(130L, new BigDecimal("150")))));

        assertThat(answer.items().get(1).nutritionAvailable()).isFalse();
        assertThat(answer.items().get(1).carbsG()).isNull();
        assertThat(answer.totals().complete()).isFalse();
        assertThat(answer.totals().carbsG()).isEqualByComparingTo("48.0"); // only the hamburger
    }

    @Test
    void anUnknownFoodIs400OnThatItem() {
        when(catalog.findAllById(anyCollection())).thenReturn(List.of(HAMBURGER));

        assertThatThrownBy(() -> service.nutrition(new FoodNutritionRequest(List.of(
                new FoodNutritionRequest.Item(50L, new BigDecimal("100")),
                new FoodNutritionRequest.Item(999L, new BigDecimal("100"))))))
                .isInstanceOfSatisfying(InvalidFieldException.class,
                        e -> assertThat(e.getField()).isEqualTo("items[1].foodCatalogId"));
    }

    // ---------- search ----------

    @Test
    void searchLooksForTheDisplayNameAndTheClassName() {
        when(catalog.search(eq("cig kofte"), eq("cig_kofte"), any())).thenReturn(List.of(LAHMACUN));

        assertThat(service.search("  Cig   Kofte ")).extracting(FoodSearchResult::displayName)
                .containsExactly("Lahmacun");
    }

    @Test
    void searchWildcardsAreNotWildcards() {
        when(catalog.search(eq("pi a"), eq("pi_a"), any())).thenReturn(List.of());

        assertThat(service.search("pi%_a")).isEmpty();
        verify(catalog).search(eq("pi a"), eq("pi_a"), any());
    }

    @Test
    void searchNeedsTwoToFiftyLetters() {
        for (String query : new String[] { null, "", " a ", "%%", "x".repeat(51) }) {
            assertThatThrownBy(() -> service.search(query)).isInstanceOf(InvalidFieldException.class);
        }
        verifyNoInteractions(catalog);
    }

    @Test
    void displayNameOfAClassName() {
        assertThat(FoodRecognitionService.displayName("chicken_curry")).isEqualTo("Chicken curry");
        assertThat(FoodRecognitionService.displayName("pizza")).isEqualTo("Pizza");
    }

    // ---------- helpers ----------

    private void assertRefused(MockMultipartFile file, String message) {
        assertThatThrownBy(() -> service.recognize(file))
                .isInstanceOfSatisfying(InvalidFieldException.class, e -> {
                    assertThat(e.getField()).isEqualTo("image");
                    assertThat(e.getMessage()).isEqualTo(message);
                });
    }

    private void modelSays(FastApiFoodResult.Prediction... guesses) {
        when(client.predict(any(), any(), any())).thenReturn(new FastApiFoodResult(true, "ResNet50", List.of(guesses)));
    }

    private static FastApiFoodResult.Prediction guess(String food, double confidence) {
        return new FastApiFoodResult.Prediction(food, confidence);
    }

    private static MockMultipartFile photo(String format) throws IOException {
        return new MockMultipartFile("image", "meal." + format, "image/" + format, imageBytes(format, 32, 24));
    }

    private static byte[] imageBytes(String format, int width, int height) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB), format, out);
        return out.toByteArray();
    }

    /** PNG signature + a valid IHDR chunk, nothing else. */
    private static byte[] pngHeader(int width, int height) {
        ByteBuffer ihdr = ByteBuffer.allocate(17);
        ihdr.put("IHDR".getBytes(StandardCharsets.US_ASCII)).putInt(width).putInt(height)
                .put((byte) 8).put((byte) 2).put((byte) 0).put((byte) 0).put((byte) 0);
        CRC32 crc = new CRC32();
        crc.update(ihdr.array());
        ByteBuffer png = ByteBuffer.allocate(8 + 4 + 17 + 4);
        png.put(new byte[] { (byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n' })
                .putInt(13).put(ihdr.array()).putInt((int) crc.getValue());
        return png.array();
    }
}

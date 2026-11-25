package com.diamate.backend.service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.diamate.backend.ai.FastApiFoodResult;
import com.diamate.backend.ai.FoodVisionClient;
import com.diamate.backend.api.dto.request.FoodNutritionRequest;
import com.diamate.backend.api.dto.response.FoodNutritionResponse;
import com.diamate.backend.api.dto.response.FoodRecognitionResponse;
import com.diamate.backend.api.dto.response.FoodSearchResult;
import com.diamate.backend.entity.FoodCatalogItem;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.repository.FoodCatalogRepository;

/**
 * Food Vision: food recognition from a meal photo (Ayşenur's food-vision-service: ResNet50 + YOLO food regions) and
 * the nutrition of the confirmed foods.
 *
 * 1. recognize: the photo is checked here, sent to the service and forgotten (not stored by the backend, the service
 *    keeps it in memory). The model's guesses, for the whole photo and for each food region, get approximate
 *    nutrition and portion options from food_catalog.
 * 2. search: the "wrong food?" picker.
 * 3. nutrition: the patient's corrected foods and amounts -> nutrition per food and for the meal.
 *
 * Nothing is saved: a photo guess can be wrong (the model is right about 77 % of the time on its test set) and the
 * nutrition values are rough estimates, so only a meal the patient has confirmed is saved, with the meal log endpoint.
 */
@Service
public class FoodRecognitionService {

    /** The app shows at most this many guesses per dish. */
    static final int MAX_PREDICTIONS = 3;

    /** Below this the best guess is not suggested as the answer (FoodRecognitionResponse.lowConfidence). */
    static final double LOW_CONFIDENCE = 0.5;

    /** At most this many search results. */
    static final int MAX_SEARCH_RESULTS = 20;

    /** Portion sizes offered with one tap: size -> factor of the typical serving. */
    static final Map<String, String> PORTIONS = portions();

    static final String NOTE = "Photo recognition can be wrong and the nutrition values are rough estimates. "
            + "Check the food and the amount before saving. Do not use these values to calculate an insulin dose.";

    static final String NUTRITION_NOTE = "Rough estimates for the amounts you chose. Check them before saving. "
            + "Do not use these values to calculate an insulin dose.";

    private final FoodVisionClient foodVisionClient;
    private final FoodCatalogRepository foodCatalogRepository;

    public FoodRecognitionService(FoodVisionClient foodVisionClient, FoodCatalogRepository foodCatalogRepository) {
        this.foodVisionClient = foodVisionClient;
        this.foodCatalogRepository = foodCatalogRepository;
    }

    /**
     * Not @Transactional on purpose: the model call can take seconds, and a transaction would hold a database
     * connection for all that time. The one catalog query runs in its own short read.
     */
    public FoodRecognitionResponse recognize(MultipartFile image) {
        ImageFile file = ImageFile.check(image);
        FastApiFoodResult result = foodVisionClient.predict(file.bytes(), file.filename(), file.contentType());

        List<FastApiFoodResult.Prediction> guesses = best(result.topPredictions());
        List<FastApiFoodResult.Item> regions = result.items() == null ? List.of() : result.items();
        List<List<FastApiFoodResult.Prediction>> regionGuesses = regions.stream()
                .map(region -> best(region.topPredictions())).toList();

        // One query for every food named anywhere in the answer.
        Map<String, FoodCatalogItem> catalog = catalog(Stream.concat(guesses.stream(),
                regionGuesses.stream().flatMap(List::stream)).map(FastApiFoodResult.Prediction::food).toList());

        List<FoodRecognitionResponse.Prediction> predictions = predictions(guesses, catalog);
        List<FoodRecognitionResponse.DetectedFood> items = new ArrayList<>();
        for (int i = 0; i < regions.size(); i++) {
            List<FoodRecognitionResponse.Prediction> regionPredictions = predictions(regionGuesses.get(i), catalog);
            items.add(new FoodRecognitionResponse.DetectedFood(regions.get(i).box(),
                    regionPredictions.getFirst().confidence() < LOW_CONFIDENCE, regionPredictions));
        }
        boolean lowConfidence = predictions.getFirst().confidence() < LOW_CONFIDENCE;
        return new FoodRecognitionResponse(result.model(), lowConfidence, true, predictions, items.size() >= 2,
                items, NOTE);
    }

    /** Foods for the "wrong food?" picker, by display name or class name ("cig kofte", "Çiğ", "pizza"). */
    public List<FoodSearchResult> search(String query) {
        String text = query == null ? "" : query.strip().toLowerCase(Locale.ROOT)
                // LIKE wildcards typed by the user are taken as nothing, not as "anything".
                .replace("%", "").replace("_", " ").replaceAll("\\s+", " ");
        if (text.length() < 2) {
            throw new InvalidFieldException("q", "Type at least 2 letters");
        }
        if (text.length() > 50) {
            throw new InvalidFieldException("q", "Search text must be at most 50 characters");
        }
        String nameText = text.replace(' ', '_');
        return foodCatalogRepository.search(text, nameText, PageRequest.of(0, MAX_SEARCH_RESULTS)).stream()
                .map(item -> new FoodSearchResult(item.getId(), item.getName(), item.getDisplayName(),
                        item.getKcalPer100g(), item.getCarbsGPer100g(), item.getProteinGPer100g(),
                        item.getFatGPer100g(), item.getDefaultServingG(), item.isVerified()))
                .toList();
    }

    /**
     * The nutrition of each confirmed food for its amount and of the whole meal. An unknown food is a 400 on that
     * item; a food without nutrition values is listed with nulls and makes the totals incomplete (never 0 g).
     */
    public FoodNutritionResponse nutrition(FoodNutritionRequest request) {
        Map<Long, FoodCatalogItem> catalog = foodCatalogRepository
                .findAllById(request.items().stream().map(FoodNutritionRequest.Item::foodCatalogId).toList()).stream()
                .collect(Collectors.toMap(FoodCatalogItem::getId, Function.identity()));

        List<FoodNutritionResponse.Item> items = new ArrayList<>();
        BigDecimal grams = BigDecimal.ZERO;
        BigDecimal carbs = BigDecimal.ZERO;
        BigDecimal kcal = BigDecimal.ZERO;
        BigDecimal protein = BigDecimal.ZERO;
        BigDecimal fat = BigDecimal.ZERO;
        boolean complete = true;
        boolean verified = true;
        for (int i = 0; i < request.items().size(); i++) {
            FoodNutritionRequest.Item wanted = request.items().get(i);
            FoodCatalogItem item = catalog.get(wanted.foodCatalogId());
            if (item == null) {
                throw new InvalidFieldException("items[" + i + "].foodCatalogId", "Unknown food");
            }
            FoodNutrition values = FoodNutrition.of(item, wanted.grams());
            items.add(new FoodNutritionResponse.Item(item.getId(), item.getName(), item.getDisplayName(),
                    wanted.grams(), values.carbsG(), values.kcal(), values.proteinG(), values.fatG(),
                    values.complete(), item.isVerified()));
            grams = grams.add(wanted.grams());
            complete &= values.complete();
            verified &= item.isVerified();
            if (values.complete()) {
                carbs = carbs.add(values.carbsG());
                kcal = kcal.add(values.kcal());
                protein = protein.add(values.proteinG());
                fat = fat.add(values.fatG());
            }
        }
        return new FoodNutritionResponse(items,
                new FoodNutritionResponse.Totals(grams, carbs, kcal, protein, fat, complete, verified && complete),
                NUTRITION_NOTE);
    }

    private static List<FastApiFoodResult.Prediction> best(List<FastApiFoodResult.Prediction> guesses) {
        return guesses.stream()
                .sorted((a, b) -> Double.compare(b.confidence(), a.confidence()))
                .limit(MAX_PREDICTIONS)
                .toList();
    }

    private Map<String, FoodCatalogItem> catalog(Collection<String> foods) {
        return foodCatalogRepository.findByNameIn(foods.stream().distinct().toList()).stream()
                .collect(Collectors.toMap(FoodCatalogItem::getName, Function.identity(), (a, b) -> a));
    }

    private static List<FoodRecognitionResponse.Prediction> predictions(List<FastApiFoodResult.Prediction> guesses,
            Map<String, FoodCatalogItem> catalog) {
        return guesses.stream().map(guess -> prediction(guess, catalog.get(guess.food()))).toList();
    }

    private static FoodRecognitionResponse.Prediction prediction(FastApiFoodResult.Prediction guess,
            FoodCatalogItem item) {
        if (item == null) {
            return new FoodRecognitionResponse.Prediction(guess.food(), displayName(guess.food()), guess.confidence(),
                    null, null, null, null, null, null, null, null, null, null, List.of(), false);
        }
        BigDecimal serving = item.getDefaultServingG();
        FoodNutrition perServing = FoodNutrition.of(item, serving);
        return new FoodRecognitionResponse.Prediction(guess.food(), item.getDisplayName(), guess.confidence(),
                item.getId(), item.getKcalPer100g(), item.getCarbsGPer100g(), item.getProteinGPer100g(),
                item.getFatGPer100g(), serving, perServing.carbsG(), perServing.kcal(), perServing.proteinG(),
                perServing.fatG(), portionOptions(item), item.isVerified());
    }

    /** Small / medium / large of the typical serving; none when the serving or the carbs are not known. */
    static List<FoodRecognitionResponse.PortionOption> portionOptions(FoodCatalogItem item) {
        if (item.getDefaultServingG() == null || item.getCarbsGPer100g() == null) {
            return List.of();
        }
        return PORTIONS.entrySet().stream().map(portion -> {
            BigDecimal grams = FoodNutrition.grams(item.getDefaultServingG(), portion.getValue());
            FoodNutrition values = FoodNutrition.of(item, grams);
            return new FoodRecognitionResponse.PortionOption(portion.getKey(), grams, values.carbsG(), values.kcal(),
                    values.proteinG(), values.fatG());
        }).toList();
    }

    private static Map<String, String> portions() {
        Map<String, String> portions = new LinkedHashMap<>();
        portions.put("SMALL", "0.5");
        portions.put("MEDIUM", "1");
        portions.put("LARGE", "1.5");
        return Collections.unmodifiableMap(portions); // keeps the order: small, medium, large
    }

    /** "chicken_curry" -> "Chicken curry", for a class that is not in the catalog. */
    static String displayName(String food) {
        String words = food.replace('_', ' ').strip();
        return words.isEmpty() ? food : Character.toUpperCase(words.charAt(0)) + words.substring(1);
    }
}

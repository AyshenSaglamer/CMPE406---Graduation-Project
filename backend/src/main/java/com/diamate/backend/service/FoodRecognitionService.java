package com.diamate.backend.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.diamate.backend.ai.FastApiFoodResult;
import com.diamate.backend.ai.FoodVisionClient;
import com.diamate.backend.api.dto.response.FoodRecognitionResponse;
import com.diamate.backend.entity.FoodCatalogItem;
import com.diamate.backend.repository.FoodCatalogRepository;

/**
 * Food recognition from a meal photo (Ayşenur's food-vision-service, ResNet50). The photo is checked here, sent to the
 * service and forgotten: it is not stored by the backend, and /predict-food keeps it in memory only. The model's
 * guesses get approximate nutrition from food_catalog.
 *
 * Nothing is saved: a photo guess can be wrong (the model is right about 77 % of the time on its test set) and the
 * nutrition values are rough estimates, so only a meal the patient has confirmed is saved, with the meal log endpoint.
 */
@Service
public class FoodRecognitionService {

    /** The app shows at most this many guesses. */
    static final int MAX_PREDICTIONS = 3;

    /** Below this the best guess is not suggested as the answer (FoodRecognitionResponse.lowConfidence). */
    static final double LOW_CONFIDENCE = 0.5;

    static final String NOTE = "Photo recognition can be wrong and the nutrition values are rough estimates. "
            + "Check the food and the amount before saving. Do not use these values to calculate an insulin dose.";

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

        List<FastApiFoodResult.Prediction> guesses = result.topPredictions().stream()
                .sorted((a, b) -> Double.compare(b.confidence(), a.confidence()))
                .limit(MAX_PREDICTIONS)
                .toList();
        Map<String, FoodCatalogItem> catalog = foodCatalogRepository
                .findByNameIn(guesses.stream().map(FastApiFoodResult.Prediction::food).toList()).stream()
                .collect(Collectors.toMap(FoodCatalogItem::getName, Function.identity(), (a, b) -> a));

        List<FoodRecognitionResponse.Prediction> predictions = guesses.stream()
                .map(guess -> prediction(guess, catalog.get(guess.food())))
                .toList();
        boolean lowConfidence = predictions.getFirst().confidence() < LOW_CONFIDENCE;
        return new FoodRecognitionResponse(result.model(), lowConfidence, true, predictions, NOTE);
    }

    private static FoodRecognitionResponse.Prediction prediction(FastApiFoodResult.Prediction guess,
            FoodCatalogItem item) {
        if (item == null) {
            return new FoodRecognitionResponse.Prediction(guess.food(), displayName(guess.food()), guess.confidence(),
                    null, null, null, null, null, false);
        }
        BigDecimal perServing = item.getCarbsGPer100g() == null || item.getDefaultServingG() == null ? null
                : item.getCarbsGPer100g().multiply(item.getDefaultServingG())
                        .divide(BigDecimal.valueOf(100), 1, RoundingMode.HALF_UP);
        return new FoodRecognitionResponse.Prediction(guess.food(), item.getDisplayName(), guess.confidence(),
                item.getId(), item.getKcalPer100g(), item.getCarbsGPer100g(), item.getDefaultServingG(), perServing,
                item.isVerified());
    }

    /** "chicken_curry" -> "Chicken curry", for a class that is not in the catalog. */
    static String displayName(String food) {
        String words = food.replace('_', ' ').strip();
        return words.isEmpty() ? food : Character.toUpperCase(words.charAt(0)) + words.substring(1);
    }
}

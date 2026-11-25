package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;
import java.util.List;

/**
 * Answer of POST /api/v1/ai/food: what the photo model thinks is on the plate, with approximate nutrition from
 * food_catalog. Nothing is saved: the patient picks or corrects the foods and the amounts in the app (the amounts can
 * be recalculated with POST /api/v1/ai/food/nutrition), which then saves a meal log.
 *
 * - model: the model of the food photo service, e.g. "ResNet50".
 * - lowConfidence: true when even the best whole-photo guess is below 50 %: the app should ask the patient to choose
 *   or type the food instead of suggesting the first one.
 * - requiresConfirmation: always true; a guess is never saved on its own.
 * - predictions: the whole photo as one dish, at most 3 guesses, best first.
 * - multipleFoods: true when the photo service found two or more separate foods; then items is the better answer.
 * - items: each food region of the photo with its own guesses (at most 5 regions, empty when none were found).
 * - note: what the numbers are (shown to the patient).
 */
public record FoodRecognitionResponse(String model, boolean lowConfidence, boolean requiresConfirmation,
        List<Prediction> predictions, boolean multipleFoods, List<DetectedFood> items, String note) {

    /** Without food regions (one dish for the whole photo). */
    public FoodRecognitionResponse(String model, boolean lowConfidence, boolean requiresConfirmation,
            List<Prediction> predictions, String note) {
        this(model, lowConfidence, requiresConfirmation, predictions, false, List.of(), note);
    }

    /**
     * One guess.
     * - food: the model's class name (e.g. "apple_pie"), displayName: the name to show ("Apple pie").
     * - confidence: 0..1.
     * - foodCatalogId: food_catalog.id, null if the food is not in the catalog.
     * - kcalPer100g, carbsGPer100g, proteinGPer100g, fatGPer100g: rough estimates per 100 g, null if not known.
     * - typicalServingG: a usual portion in grams; carbsGPerServing, kcalPerServing, proteinGPerServing,
     *   fatGPerServing: the values for that portion, one decimal place.
     * - portionOptions: small / medium / large portions to choose from with one tap (empty when the serving or the
     *   nutrition is not known). Any other amount: POST /api/v1/ai/food/nutrition.
     * - nutritionVerified: false = rough estimate, never to be used for insulin dosing.
     */
    public record Prediction(String food, String displayName, double confidence, Long foodCatalogId,
            BigDecimal kcalPer100g, BigDecimal carbsGPer100g, BigDecimal proteinGPer100g, BigDecimal fatGPer100g,
            BigDecimal typicalServingG, BigDecimal carbsGPerServing, BigDecimal kcalPerServing,
            BigDecimal proteinGPerServing, BigDecimal fatGPerServing, List<PortionOption> portionOptions,
            boolean nutritionVerified) {
    }

    /**
     * A portion size: SMALL (half a typical serving), MEDIUM (a typical serving) or LARGE (one and a half), with its
     * grams and the nutrition of that amount.
     */
    public record PortionOption(String size, BigDecimal grams, BigDecimal carbsG, BigDecimal kcal,
            BigDecimal proteinG, BigDecimal fatG) {
    }

    /**
     * One food region of the photo.
     * - box: [x1, y1, x2, y2], each 0..1 of the photo's width / height (to draw a frame on the photo).
     * - lowConfidence: the best guess for this region is below 50 %.
     * - predictions: at most 3 guesses for this region, best first.
     */
    public record DetectedFood(List<Double> box, boolean lowConfidence, List<Prediction> predictions) {
    }
}

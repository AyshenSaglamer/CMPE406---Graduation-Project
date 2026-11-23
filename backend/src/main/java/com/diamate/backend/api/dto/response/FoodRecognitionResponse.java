package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;
import java.util.List;

/**
 * Answer of POST /api/v1/ai/food: the photo model's best guesses (at most 3, best first) with approximate nutrition
 * from food_catalog. Nothing is saved: the patient picks or corrects the food and the amount in the app, which then
 * saves a meal log.
 *
 * - model: the model of the food photo service, e.g. "ResNet50".
 * - lowConfidence: true when even the best guess is below 50 %: the app should ask the patient to choose or type the
 *   food instead of suggesting the first one.
 * - requiresConfirmation: always true; a guess is never saved on its own.
 * - note: what the numbers are (shown to the patient).
 */
public record FoodRecognitionResponse(String model, boolean lowConfidence, boolean requiresConfirmation,
        List<Prediction> predictions, String note) {

    /**
     * One guess.
     * - food: the model's class name (e.g. "apple_pie"), displayName: the name to show ("Apple pie").
     * - confidence: 0..1.
     * - foodCatalogId: food_catalog.id, null if the food is not in the catalog.
     * - kcalPer100g, carbsGPer100g, typicalServingG, carbsGPerServing: rough estimates, null if not known.
     *   carbsGPerServing = carbsGPer100g x typicalServingG / 100, one decimal place.
     * - nutritionVerified: false = rough estimate, never to be used for insulin dosing.
     */
    public record Prediction(String food, String displayName, double confidence, Long foodCatalogId,
            BigDecimal kcalPer100g, BigDecimal carbsGPer100g, BigDecimal typicalServingG, BigDecimal carbsGPerServing,
            boolean nutritionVerified) {
    }
}

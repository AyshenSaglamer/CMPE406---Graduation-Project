package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;
import java.util.List;

/**
 * Answer of POST /api/v1/ai/food/nutrition: the nutrition of each food for the amount the patient chose, and of the
 * whole meal. Rough estimates unless nutritionVerified; never to be used for insulin dosing.
 *
 * - items: in the order of the request.
 * - totals: the sum of the items. A food without nutrition values is NOT counted as 0 g: totals.complete is then
 *   false and the app asks the patient for the carbs of that food.
 */
public record FoodNutritionResponse(List<Item> items, Totals totals, String note) {

    /** carbsG, kcal, proteinG, fatG: for the given grams, one decimal place, null when the catalog has no value. */
    public record Item(long foodCatalogId, String food, String displayName, BigDecimal grams, BigDecimal carbsG,
            BigDecimal kcal, BigDecimal proteinG, BigDecimal fatG, boolean nutritionAvailable,
            boolean nutritionVerified) {
    }

    /** complete: every item had all four values. verified: every item's values are checked (not rough estimates). */
    public record Totals(BigDecimal grams, BigDecimal carbsG, BigDecimal kcal, BigDecimal proteinG, BigDecimal fatG,
            boolean complete, boolean verified) {
    }
}

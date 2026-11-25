package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;

/**
 * One food of GET /api/v1/ai/food/search: for the "wrong food?" picker after a photo, or to find a food by name.
 * Values per 100 g and the typical serving are rough estimates unless nutritionVerified; null when not known.
 */
public record FoodSearchResult(long foodCatalogId, String food, String displayName, BigDecimal kcalPer100g,
        BigDecimal carbsGPer100g, BigDecimal proteinGPer100g, BigDecimal fatGPer100g, BigDecimal typicalServingG,
        boolean nutritionVerified) {
}

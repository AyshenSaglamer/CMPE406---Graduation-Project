package com.diamate.backend.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

import com.diamate.backend.entity.FoodCatalogItem;

/**
 * Nutrition of an amount of a catalog food: per-100 g value x grams / 100, one decimal place. A value the catalog
 * does not have stays null; it is never turned into 0, because 0 g of carbohydrate would be a wrong answer.
 */
record FoodNutrition(BigDecimal carbsG, BigDecimal kcal, BigDecimal proteinG, BigDecimal fatG) {

    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);

    static FoodNutrition of(FoodCatalogItem item, BigDecimal grams) {
        return new FoodNutrition(scale(item.getCarbsGPer100g(), grams), scale(item.getKcalPer100g(), grams),
                scale(item.getProteinGPer100g(), grams), scale(item.getFatGPer100g(), grams));
    }

    /** All four values are known. */
    boolean complete() {
        return carbsG != null && kcal != null && proteinG != null && fatG != null;
    }

    static BigDecimal scale(BigDecimal per100g, BigDecimal grams) {
        return per100g == null || grams == null ? null
                : per100g.multiply(grams).divide(HUNDRED, 1, RoundingMode.HALF_UP);
    }

    /** grams x factor, one decimal place (portion sizes). */
    static BigDecimal grams(BigDecimal grams, String factor) {
        return grams.multiply(new BigDecimal(factor)).setScale(1, RoundingMode.HALF_UP);
    }
}

package com.diamate.backend.api.dto.request;

import java.math.BigDecimal;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Body of POST /api/v1/ai/food/nutrition: the foods of a meal as the patient confirmed or corrected them, each with
 * an amount in grams. Answers the nutrition of each food and of the whole meal; nothing is saved.
 * Example: {"items": [{"foodCatalogId": 76, "grams": 150}, {"foodCatalogId": 130, "grams": 80}]}
 */
public record FoodNutritionRequest(

        @NotEmpty(message = "At least one food is required")
        @Size(max = 20, message = "At most 20 foods per meal")
        List<@NotNull(message = "A food is required") @Valid Item> items) {

    public record Item(

            @NotNull(message = "Food is required")
            Long foodCatalogId,

            @NotNull(message = "Amount is required")
            @DecimalMin(value = "1", message = "Amount must be at least 1 g")
            @DecimalMax(value = "2000", message = "Amount must be at most 2000 g")
            @Digits(integer = 4, fraction = 1, message = "Amount can have at most 1 decimal place")
            BigDecimal grams) {
    }
}

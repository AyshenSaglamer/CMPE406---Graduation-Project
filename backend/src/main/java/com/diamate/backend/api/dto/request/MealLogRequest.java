package com.diamate.backend.api.dto.request;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.diamate.backend.entity.MealType;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Body of POST / PUT for meal logs. Nutrition values are optional (the patient may only know the carbs).
 * One decimal place, like the numeric(…,1) columns of meal_logs.
 */
public record MealLogRequest(

        @NotNull(message = "Meal type is required")
        MealType mealType, // BREAKFAST, LUNCH, DINNER, SNACK, OTHER

        @NotNull(message = "Meal time is required")
        Instant eatenAt,

        @Size(max = 1000, message = "Description must be at most 1000 characters")
        String description,

        @DecimalMin(value = "0", message = "Carbs must be 0 or more")
        @DecimalMax(value = "1000", message = "Carbs must be at most 1000 g")
        @Digits(integer = 4, fraction = 1, message = "Carbs can have at most 1 decimal place")
        BigDecimal carbsG,

        @DecimalMin(value = "0", message = "Calories must be 0 or more")
        @DecimalMax(value = "10000", message = "Calories must be at most 10000 kcal")
        @Digits(integer = 5, fraction = 1, message = "Calories can have at most 1 decimal place")
        BigDecimal caloriesKcal,

        @DecimalMin(value = "0", message = "Protein must be 0 or more")
        @DecimalMax(value = "1000", message = "Protein must be at most 1000 g")
        @Digits(integer = 4, fraction = 1, message = "Protein can have at most 1 decimal place")
        BigDecimal proteinG,

        @DecimalMin(value = "0", message = "Fat must be 0 or more")
        @DecimalMax(value = "1000", message = "Fat must be at most 1000 g")
        @Digits(integer = 4, fraction = 1, message = "Fat can have at most 1 decimal place")
        BigDecimal fatG,

        @Size(max = 1000, message = "Notes must be at most 1000 characters")
        String notes,

        EntrySource source,

        UUID clientUuid) {
}

package com.diamate.backend.api.dto.request;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.diamate.backend.entity.MealContext;
import com.diamate.backend.entity.MealType;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Body of POST /api/v1/patients/{patientId}/ai-entries: the entries of an /ai/parse answer that the patient confirmed
 * (and maybe corrected) in the app. intent, value, unit and activity are copied from the parse answer; the other
 * fields are optional and come from the app.
 */
public record AiEntriesRequest(

        @NotEmpty(message = "At least one entry is required")
        @Size(max = 10, message = "At most 10 entries can be saved at once")
        List<@NotNull(message = "Entry must not be empty") @Valid Entry> entries) {

    public record Entry(

            @NotNull(message = "Intent is required") // LOG_GLUCOSE, LOG_INSULIN, LOG_MEAL, LOG_ACTIVITY
            AiIntent intent,

            // The upper bound and the digit limit are checked before anything is converted: a short number such as
            // 1e999999999 would otherwise make the conversion (e.g. "5 km" notes) build a string of a billion digits.
            @NotNull(message = "Value is required")
            @DecimalMin(value = "0", inclusive = false, message = "Value must be greater than 0")
            @DecimalMax(value = "100000", message = "Value must be at most 100000")
            @Digits(integer = 6, fraction = 3, message = "Value can have at most 6 digits before and 3 after the decimal point")
            BigDecimal value,

            // As the assistant returns it: "mg/dL", "units", "grams"; for activities "minutes", "hours", "seconds",
            // "km", "miles", "meters" or "repetitions". Empty means the usual unit (not allowed for activities).
            @Size(max = 20, message = "Unit must be at most 20 characters")
            String unit,

            @Size(max = 50, message = "Activity must be at most 50 characters")
            String activity, // the activity word the assistant found, e.g. "walked"; required for LOG_ACTIVITY

            Instant at, // when it happened; empty = now

            MealType mealType, // LOG_MEAL only; empty = OTHER (the assistant does not say which meal)

            MealContext mealContext, // LOG_GLUCOSE only; optional

            UUID clientUuid) { // same meaning as on the log endpoints: a resent entry is not saved twice
    }
}

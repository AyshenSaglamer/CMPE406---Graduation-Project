package com.diamate.backend.api.dto.request;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.diamate.backend.entity.ActivityIntensity;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Body of POST / PUT for activity logs. */
public record ActivityLogRequest(

        @NotBlank(message = "Activity type is required")
        @Size(max = 50, message = "Activity type must be at most 50 characters")
        String activityType, // free text, e.g. "walking"

        @NotNull(message = "Start time is required")
        Instant startedAt,

        @DecimalMin(value = "0", inclusive = false, message = "Duration must be greater than 0")
        @DecimalMax(value = "1440", message = "Duration must be at most 1440 minutes (one day)")
        @Digits(integer = 4, fraction = 1, message = "Duration can have at most 1 decimal place")
        BigDecimal durationMinutes,

        @Min(value = 0, message = "Steps must be 0 or more")
        @Max(value = 200000, message = "Steps must be at most 200000")
        Integer steps,

        @Min(value = 20, message = "Average heart rate must be at least 20 bpm")
        @Max(value = 260, message = "Average heart rate must be at most 260 bpm")
        Integer avgHeartRate,

        @DecimalMin(value = "0", message = "Calories must be 0 or more")
        @DecimalMax(value = "10000", message = "Calories must be at most 10000 kcal")
        @Digits(integer = 5, fraction = 1, message = "Calories can have at most 1 decimal place")
        BigDecimal caloriesKcal,

        ActivityIntensity intensity, // optional: LOW, MODERATE, HIGH

        @Size(max = 1000, message = "Notes must be at most 1000 characters")
        String notes,

        EntrySource source, // MANUAL (default) or AI_ASSISTANT; kept on PUT (where a log came from never changes)

        UUID clientUuid) {
}

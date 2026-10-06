package com.diamate.backend.api.dto.request;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.diamate.backend.entity.InsulinDeliveryMethod;
import com.diamate.backend.entity.InsulinType;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Body of POST / PUT for insulin logs. Limits follow the CHECK constraints of insulin_logs. */
public record InsulinLogRequest(

        @NotNull(message = "Dose is required")
        @DecimalMin(value = "0", inclusive = false, message = "Dose must be greater than 0")
        @DecimalMax(value = "300", message = "Dose must be at most 300 units")
        @Digits(integer = 3, fraction = 2, message = "Dose can have at most 2 decimal places")
        BigDecimal doseUnits,

        InsulinType insulinType, // optional, default OTHER: RAPID, SHORT, INTERMEDIATE, LONG, MIXED, OTHER

        InsulinDeliveryMethod deliveryMethod, // optional, default OTHER: PEN, SYRINGE, PUMP_BOLUS, PUMP_BASAL, OTHER

        @Size(max = 100, message = "Product name must be at most 100 characters")
        String productName, // e.g. "NovoRapid"

        @NotNull(message = "Administration time is required")
        Instant administeredAt,

        Long mealLogId, // optional: the meal this dose was for (must be the same patient's meal)

        @Size(max = 1000, message = "Notes must be at most 1000 characters")
        String notes,

        EntrySource source,

        UUID clientUuid) {
}

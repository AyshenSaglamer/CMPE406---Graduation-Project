package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.diamate.backend.entity.InsulinDeliveryMethod;
import com.diamate.backend.entity.InsulinLog;
import com.diamate.backend.entity.InsulinSource;
import com.diamate.backend.entity.InsulinType;

public record InsulinLogResponse(long id, long patientId, BigDecimal doseUnits, InsulinType insulinType,
        InsulinDeliveryMethod deliveryMethod, String productName, Instant administeredAt, Long mealLogId,
        InsulinSource source, String notes, UUID clientUuid, Instant createdAt, Instant updatedAt) {

    public static InsulinLogResponse from(InsulinLog log) {
        return new InsulinLogResponse(log.getId(), log.getPatientId(), log.getDoseUnits(), log.getInsulinType(),
                log.getDeliveryMethod(), log.getProductName(), log.getAdministeredAt(), log.getMealLogId(),
                log.getSource(), log.getNotes(), log.getClientUuid(), log.getCreatedAt(), log.getUpdatedAt());
    }
}

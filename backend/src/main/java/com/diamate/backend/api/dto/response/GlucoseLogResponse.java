package com.diamate.backend.api.dto.response;

import java.time.Instant;
import java.util.UUID;

import com.diamate.backend.entity.GlucoseLog;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.MealContext;

public record GlucoseLogResponse(long id, long patientId, int glucoseValue, Instant measurementTime,
        MealContext mealContext, GlucoseSource source, String notes, UUID clientUuid, Instant createdAt,
        Instant updatedAt) {

    public static GlucoseLogResponse from(GlucoseLog log) {
        return new GlucoseLogResponse(log.getId(), log.getPatientId(), log.getGlucoseValue(), log.getMeasurementTime(),
                log.getMealContext(), log.getSource(), log.getNotes(), log.getClientUuid(), log.getCreatedAt(),
                log.getUpdatedAt());
    }
}

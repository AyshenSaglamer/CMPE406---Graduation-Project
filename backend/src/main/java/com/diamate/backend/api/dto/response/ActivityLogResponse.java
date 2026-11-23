package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.diamate.backend.entity.ActivityIntensity;
import com.diamate.backend.entity.ActivityLog;
import com.diamate.backend.entity.ActivitySource;

public record ActivityLogResponse(long id, long patientId, String activityType, Instant startedAt,
        BigDecimal durationMinutes, Integer steps, Integer avgHeartRate, BigDecimal caloriesKcal,
        ActivityIntensity intensity, ActivitySource source, String notes, UUID clientUuid, Instant createdAt,
        Instant updatedAt) {

    public static ActivityLogResponse from(ActivityLog log) {
        Integer heartRate = log.getAvgHeartRate() == null ? null : log.getAvgHeartRate().intValue();
        return new ActivityLogResponse(log.getId(), log.getPatientId(), log.getActivityType(), log.getStartedAt(),
                log.getDurationMinutes(), log.getSteps(), heartRate, log.getCaloriesKcal(), log.getIntensity(),
                log.getSource(), log.getNotes(), log.getClientUuid(), log.getCreatedAt(), log.getUpdatedAt());
    }
}

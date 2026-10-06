package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.diamate.backend.entity.MealLog;
import com.diamate.backend.entity.MealSource;
import com.diamate.backend.entity.MealType;

public record MealLogResponse(long id, long patientId, MealType mealType, Instant eatenAt, String description,
        BigDecimal carbsG, BigDecimal caloriesKcal, BigDecimal proteinG, BigDecimal fatG, MealSource source,
        String notes, UUID clientUuid, Instant createdAt, Instant updatedAt) {

    public static MealLogResponse from(MealLog log) {
        return new MealLogResponse(log.getId(), log.getPatientId(), log.getMealType(), log.getEatenAt(),
                log.getDescription(), log.getCarbsG(), log.getCaloriesKcal(), log.getProteinG(), log.getFatG(),
                log.getSource(), log.getNotes(), log.getClientUuid(), log.getCreatedAt(), log.getUpdatedAt());
    }
}

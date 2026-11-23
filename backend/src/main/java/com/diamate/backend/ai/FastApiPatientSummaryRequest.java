package com.diamate.backend.ai;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Body of ai-service's POST /api/v1/integration/patient-summary (BackendHistoryRequest in
 * ai-service/models/integration_schemas.py). Database access and authorization stay in the backend; the AI service
 * gets only the fields it analyses (no notes, descriptions or other free text).
 *
 * The AI service requires carbsG and durationMinutes: meals without carbs and activities without a duration are left
 * out by the backend (AiService) instead of failing the whole summary.
 */
public record FastApiPatientSummaryRequest(
        List<Glucose> glucoseLogs,
        List<Meal> mealLogs,
        List<Activity> activityLogs,
        double rangeLow,
        double rangeHigh) {

    public record Glucose(long id, long patientId, int glucoseValue, Instant measurementTime, UUID clientUuid) {
    }

    public record Meal(long id, long patientId, Instant eatenAt, BigDecimal carbsG, UUID clientUuid) {
    }

    public record Activity(long id, long patientId, Instant startedAt, BigDecimal durationMinutes, UUID clientUuid) {
    }
}

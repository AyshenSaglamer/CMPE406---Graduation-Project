package com.diamate.backend.ai;

import java.util.List;

import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;

/**
 * Request sent from the Spring Boot backend to the
 * DiaMate FastAPI patient-summary integration endpoint.
 *
 * Database access and authorization remain in Spring Boot.
 * FastAPI receives only the health-log data required
 * for AI/analytics processing.
 */
public record FastApiPatientSummaryRequest(
        List<GlucoseLogResponse> glucoseLogs,
        List<MealLogResponse> mealLogs,
        List<ActivityLogResponse> activityLogs,
        double rangeLow,
        double rangeHigh) {
}

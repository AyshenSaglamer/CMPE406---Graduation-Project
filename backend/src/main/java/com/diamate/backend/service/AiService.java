package com.diamate.backend.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.diamate.backend.ai.AiClient;
import com.diamate.backend.ai.FastApiParseResult;
import com.diamate.backend.ai.FastApiPatientSummaryRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;

/**
 * AI assistant features that use the FastAPI service.
 *
 * Spring Boot remains responsible for authorization and database
 * access. FastAPI receives only the data required for analysis.
 */
@Service
public class AiService {

    private static final int AI_HISTORY_PAGE_SIZE = 200;

    private final AiClient aiClient;
    private final GlucoseLogService glucoseLogService;
    private final MealLogService mealLogService;
    private final ActivityLogService activityLogService;

    public AiService(
            AiClient aiClient,
            GlucoseLogService glucoseLogService,
            MealLogService mealLogService,
            ActivityLogService activityLogService) {

        this.aiClient = aiClient;
        this.glucoseLogService = glucoseLogService;
        this.mealLogService = mealLogService;
        this.activityLogService = activityLogService;
    }

    public AiParseResponse parse(String text) {
        FastApiParseResult result =
                aiClient.parseMultiple(text.trim());

        List<AiParseResponse.Entry> entries =
                result.results() == null
                        ? List.of()
                        : result.results()
                                .stream()
                                .map(e ->
                                        new AiParseResponse.Entry(
                                                e.intent(),
                                                e.status(),
                                                e.value(),
                                                e.unit(),
                                                e.activity(),
                                                e.message()))
                                .toList();

        return new AiParseResponse(
                result.status(),
                entries.size(),
                entries,
                result.message());
    }

    /**
     * Builds an AI patient summary from health logs that Spring Boot
     * has already authorized the current viewer to read.
     */
    public Map<String, Object> patientSummary(
            long viewerId,
            long patientId,
            Instant from,
            Instant to,
            double rangeLow,
            double rangeHigh) {

        List<GlucoseLogResponse> glucoseLogs =
                loadAllGlucoseLogs(
                        viewerId,
                        patientId,
                        from,
                        to);

        List<MealLogResponse> mealLogs =
                loadAllMealLogs(
                        viewerId,
                        patientId,
                        from,
                        to);

        List<ActivityLogResponse> activityLogs =
                loadAllActivityLogs(
                        viewerId,
                        patientId,
                        from,
                        to);

        FastApiPatientSummaryRequest request =
                new FastApiPatientSummaryRequest(
                        glucoseLogs,
                        mealLogs,
                        activityLogs,
                        rangeLow,
                        rangeHigh);

        return aiClient.patientSummary(request);
    }

    private List<GlucoseLogResponse> loadAllGlucoseLogs(
            long viewerId,
            long patientId,
            Instant from,
            Instant to) {

        List<GlucoseLogResponse> result =
                new ArrayList<>();

        int page = 0;

        while (true) {
            PageResponse<GlucoseLogResponse> response =
                    glucoseLogService.list(
                            viewerId,
                            patientId,
                            from,
                            to,
                            page,
                            AI_HISTORY_PAGE_SIZE);

            result.addAll(response.items());

            if (page + 1 >= response.totalPages()) {
                break;
            }

            page++;
        }

        return result;
    }

    private List<MealLogResponse> loadAllMealLogs(
            long viewerId,
            long patientId,
            Instant from,
            Instant to) {

        List<MealLogResponse> result =
                new ArrayList<>();

        int page = 0;

        while (true) {
            PageResponse<MealLogResponse> response =
                    mealLogService.list(
                            viewerId,
                            patientId,
                            from,
                            to,
                            page,
                            AI_HISTORY_PAGE_SIZE);

            result.addAll(response.items());

            if (page + 1 >= response.totalPages()) {
                break;
            }

            page++;
        }

        return result;
    }

    private List<ActivityLogResponse> loadAllActivityLogs(
            long viewerId,
            long patientId,
            Instant from,
            Instant to) {

        List<ActivityLogResponse> result =
                new ArrayList<>();

        int page = 0;

        while (true) {
            PageResponse<ActivityLogResponse> response =
                    activityLogService.list(
                            viewerId,
                            patientId,
                            from,
                            to,
                            page,
                            AI_HISTORY_PAGE_SIZE);

            result.addAll(response.items());

            if (page + 1 >= response.totalPages()) {
                break;
            }

            page++;
        }

        return result;
    }
}

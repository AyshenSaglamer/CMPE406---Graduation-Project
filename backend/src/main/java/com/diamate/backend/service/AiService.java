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

    /**
     * Parses natural-language health logging text.
     */
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
     * Builds an AI patient summary from authorized
     * glucose, meal, and activity history.
     */
    public Map<String, Object> patientSummary(
            long viewerId,
            long patientId,
            Instant from,
            Instant to,
            double rangeLow,
            double rangeHigh) {

        FastApiPatientSummaryRequest request =
                buildPatientHistoryRequest(
                        viewerId,
                        patientId,
                        from,
                        to,
                        rangeLow,
                        rangeHigh);

        return aiClient.patientSummary(request);
    }

    /**
     * Builds a personalized glucose anomaly analysis from
     * authorized patient health history.
     *
     * The analysis describes statistical unusualness relative
     * to the patient's own historical pattern. It does not
     * represent diagnosis, clinical risk, treatment advice,
     * or medication guidance.
     */
    public Map<String, Object> patientAnomaly(
            long viewerId,
            long patientId,
            Instant from,
            Instant to,
            double rangeLow,
            double rangeHigh) {

        FastApiPatientSummaryRequest request =
                buildPatientHistoryRequest(
                        viewerId,
                        patientId,
                        from,
                        to,
                        rangeLow,
                        rangeHigh);

        return aiClient.patientAnomaly(request);
    }

    /**
     * Builds a patient-history data-quality analysis from
     * authorized glucose, meal, and activity history.
     *
     * The analysis checks engineering data-quality properties
     * such as missing values, duplicate records, invalid
     * timestamps, and large logging gaps.
     *
     * This is a technical data-quality analysis and does not
     * represent medical status, diagnosis, clinical risk,
     * treatment advice, or medication guidance.
     */
    public Map<String, Object> patientDataQuality(
            long viewerId,
            long patientId,
            Instant from,
            Instant to,
            double rangeLow,
            double rangeHigh) {

        FastApiPatientSummaryRequest request =
                buildPatientHistoryRequest(
                        viewerId,
                        patientId,
                        from,
                        to,
                        rangeLow,
                        rangeHigh);

        return aiClient.patientDataQuality(request);
    }

    /**
     * Builds a model-input drift analysis from authorized
     * patient glucose, meal, and activity history.
     *
     * FastAPI compares an older reference period with newer
     * patient-history records to detect statistical changes
     * in the model-input feature distribution.
     *
     * Drift is an engineering model-monitoring signal only.
     * It does not represent diagnosis, clinical deterioration,
     * medical risk, treatment advice, or medication guidance.
     */
    public Map<String, Object> patientDrift(
            long viewerId,
            long patientId,
            Instant from,
            Instant to,
            double rangeLow,
            double rangeHigh) {

        FastApiPatientSummaryRequest request =
                buildPatientHistoryRequest(
                        viewerId,
                        patientId,
                        from,
                        to,
                        rangeLow,
                        rangeHigh);

        return aiClient.patientDrift(request);
    }

    /**
     * Builds an experimental XGBoost glucose-trend prediction
     * from authorized patient glucose, meal, and activity
     * history.
     *
     * FastAPI converts the authorized health history into the
     * shared machine-learning representation and applies the
     * saved XGBoost model.
     *
     * The response may include the predicted trend, class
     * probabilities, confidence, uncertainty, and explainable
     * AI information.
     *
     * These outputs describe experimental model behaviour
     * only. They do not represent clinical probability,
     * diagnosis, medical risk, treatment advice, or
     * medication guidance.
     */
    public Map<String, Object> patientPrediction(
            long viewerId,
            long patientId,
            Instant from,
            Instant to,
            double rangeLow,
            double rangeHigh) {

        FastApiPatientSummaryRequest request =
                buildPatientHistoryRequest(
                        viewerId,
                        patientId,
                        from,
                        to,
                        rangeLow,
                        rangeHigh);

        return aiClient.patientPrediction(request);
    }

    /**
     * Collects authorized patient history and builds the
     * request sent to FastAPI.
     *
     * Summary, anomaly, data-quality, drift, and prediction
     * analysis use the same authorized health-history
     * representation.
     */
    private FastApiPatientSummaryRequest buildPatientHistoryRequest(
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

        return new FastApiPatientSummaryRequest(
                glucoseLogs,
                mealLogs,
                activityLogs,
                rangeLow,
                rangeHigh);
    }

    /**
     * Loads all authorized glucose logs using pagination.
     */
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

    /**
     * Loads all authorized meal logs using pagination.
     */
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

    /**
     * Loads all authorized activity logs using pagination.
     */
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

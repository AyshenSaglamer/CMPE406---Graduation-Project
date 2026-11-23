package com.diamate.backend.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.diamate.backend.ai.AiAnalysis;
import com.diamate.backend.ai.AiClient;
import com.diamate.backend.ai.FastApiParseResult;
import com.diamate.backend.ai.FastApiPatientSummaryRequest;
import com.diamate.backend.ai.FastApiVoiceResult;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.api.dto.response.AiVoiceResponse;
import com.diamate.backend.entity.ActivityLog;
import com.diamate.backend.entity.GlucoseLog;
import com.diamate.backend.entity.MealLog;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.repository.ActivityLogRepository;
import com.diamate.backend.repository.GlucoseLogRepository;
import com.diamate.backend.repository.MealLogRepository;

/**
 * AI assistant features that use the FastAPI service. Nothing is saved here on purpose: text recognition can be
 * wrong, so health data is only saved after the patient confirms it in the app (log endpoints, source AI_ASSISTANT).
 */
@Service
public class AiService {

    /** An analysis covers at most a month: the logs are sent to the AI service in one request. */
    static final Duration MAX_SUMMARY_RANGE = Duration.ofDays(31);

    /** Per log type; a month of CGM data is ~8 900 readings. More means the range is too long for one request. */
    static final int MAX_SUMMARY_RECORDS = 10_000;

    /** The AI service builds its history from pairs of readings (ai-service: aggregate_events_for_ml). */
    static final int MIN_GLUCOSE_READINGS = 2;

    /** Same limits as a glucose reading (GlucoseLogRequest). */
    static final double MIN_RANGE_VALUE = 10;
    static final double MAX_RANGE_VALUE = 600;

    private final AiClient aiClient;
    private final HealthDataAccess access;
    private final GlucoseLogRepository glucoseLogRepository;
    private final MealLogRepository mealLogRepository;
    private final ActivityLogRepository activityLogRepository;
    private final Clock clock;

    public AiService(AiClient aiClient, HealthDataAccess access, GlucoseLogRepository glucoseLogRepository,
            MealLogRepository mealLogRepository, ActivityLogRepository activityLogRepository, Clock clock) {
        this.aiClient = aiClient;
        this.access = access;
        this.glucoseLogRepository = glucoseLogRepository;
        this.mealLogRepository = mealLogRepository;
        this.activityLogRepository = activityLogRepository;
        this.clock = clock;
    }

    public AiParseResponse parse(String text) {
        FastApiParseResult result = aiClient.parseMultiple(text.trim());
        List<AiParseResponse.Entry> entries = entries(result.results());
        return new AiParseResponse(result.status(), entries.size(), entries, result.message());
    }

    /**
     * Speech-to-text + NLP of a recording (Ayşen, ai-backend-integration): the same result as parse(), plus what
     * Whisper heard (transcript). Nothing is saved; the app shows the result and saves it with /ai-entries, like
     * typed text. The file is checked here first (the AI service accepts the same types and sizes).
     */
    public AiVoiceResponse parseVoice(MultipartFile audio) {
        AudioFile file = AudioFile.check(audio);
        FastApiVoiceResult result = aiClient.parseVoice(file.bytes(), file.filename(), file.contentType());
        List<AiParseResponse.Entry> entries = entries(result.results());
        return new AiVoiceResponse(result.status(), result.transcript(), entries.size(), entries, result.message());
    }

    /**
     * AI summary of a patient's glucose, meal and activity logs in [from, to) (Ayşen, ai-backend-integration).
     * Same as patientAnalysis(SUMMARY, ...).
     */
    public Map<String, Object> patientSummary(long viewerId, long patientId, Instant from, Instant to,
            double rangeLow, double rangeHigh) {
        return patientAnalysis(AiAnalysis.SUMMARY, viewerId, patientId, from, to, rangeLow, rangeHigh);
    }

    /**
     * One of the AI service's patient-history analyses (summary, anomaly, data quality, drift, prediction; Ayşen,
     * ai-backend-integration) of the logs in [from, to). All of them get the same history:
     *
     * - Access: an analysis is a report built from the glucose logs, so both the "reports" and the "glucose"
     *   permission are required; without either the patient is "not found" (404), like the log endpoints. Meals and
     *   activities are added only if the viewer may see them. Every read is audited.
     * - Window: the one of the log lists (default: last 14 days), at most 31 days, at most 10 000 logs per type.
     * - At least 2 glucose readings (400). The AI service may need more for some analyses (anomaly 6, drift 10)
     *   and then answers 422 with its own explanation, which is passed on.
     * - Meals without carbs and activities without a duration are sent too (null): the AI service leaves the
     *   unknown amount out instead of counting it as zero (ai-service 8220cc0).
     *
     * Not @Transactional, like the log lists (see HealthDataAccess).
     */
    public Map<String, Object> patientAnalysis(AiAnalysis analysis, long viewerId, long patientId, Instant from,
            Instant to, double rangeLow, double rangeHigh) {
        access.checkCanRead(viewerId, patientId, PatientDataType.REPORTS);
        access.checkCanRead(viewerId, patientId, PatientDataType.GLUCOSE_LOGS);
        requireRange(rangeLow, rangeHigh);
        LogRules.Window window = LogRules.window(from, to, 0, 1, clock);
        if (Duration.between(window.from(), window.to()).compareTo(MAX_SUMMARY_RANGE) > 0) {
            throw new InvalidFieldException("from", "An analysis covers at most 31 days");
        }
        Pageable limit = PageRequest.of(0, MAX_SUMMARY_RECORDS);

        List<FastApiPatientSummaryRequest.Glucose> glucose = upToLimit(
                glucoseLogRepository.findInRange(patientId, window.from(), window.to(), limit)).stream()
                .map(AiService::glucose).toList();
        if (glucose.size() < MIN_GLUCOSE_READINGS) {
            throw new InvalidFieldException("from",
                    "At least " + MIN_GLUCOSE_READINGS + " glucose readings are needed in this time range");
        }

        List<FastApiPatientSummaryRequest.Meal> meals = List.of();
        if (access.canRead(viewerId, patientId, PatientDataType.MEAL_LOGS)) {
            meals = upToLimit(mealLogRepository.findInRange(patientId, window.from(), window.to(), limit)).stream()
                    .map(AiService::meal).toList();
        }

        List<FastApiPatientSummaryRequest.Activity> activities = List.of();
        if (access.canRead(viewerId, patientId, PatientDataType.ACTIVITY_LOGS)) {
            activities = upToLimit(activityLogRepository.findInRange(patientId, window.from(), window.to(), limit))
                    .stream()
                    .map(AiService::activity).toList();
        }

        return aiClient.patientAnalysis(analysis,
                new FastApiPatientSummaryRequest(glucose, meals, activities, rangeLow, rangeHigh));
    }

    private static List<AiParseResponse.Entry> entries(List<FastApiParseResult.Entry> results) {
        return results == null ? List.of()
                : results.stream()
                        .map(e -> new AiParseResponse.Entry(e.intent(), e.status(), e.value(), e.unit(), e.activity(),
                                e.message()))
                        .toList();
    }

    private static void requireRange(double rangeLow, double rangeHigh) {
        String limits = "must be between " + (int) MIN_RANGE_VALUE + " and " + (int) MAX_RANGE_VALUE + " mg/dL";
        if (!(rangeLow >= MIN_RANGE_VALUE && rangeLow <= MAX_RANGE_VALUE)) {
            throw new InvalidFieldException("rangeLow", "rangeLow " + limits);
        }
        if (!(rangeHigh >= MIN_RANGE_VALUE && rangeHigh <= MAX_RANGE_VALUE)) {
            throw new InvalidFieldException("rangeHigh", "rangeHigh " + limits);
        }
        if (rangeLow >= rangeHigh) {
            throw new InvalidFieldException("rangeLow", "rangeLow must be lower than rangeHigh");
        }
    }

    private static <T> List<T> upToLimit(Page<T> page) {
        if (page.hasNext()) {
            throw new InvalidFieldException("from", "Too many records in this time range, choose a shorter one");
        }
        return page.getContent();
    }

    private static FastApiPatientSummaryRequest.Glucose glucose(GlucoseLog log) {
        return new FastApiPatientSummaryRequest.Glucose(log.getId(), log.getPatientId(), log.getGlucoseValue(),
                log.getMeasurementTime(), log.getClientUuid());
    }

    private static FastApiPatientSummaryRequest.Meal meal(MealLog log) {
        return new FastApiPatientSummaryRequest.Meal(log.getId(), log.getPatientId(), log.getEatenAt(),
                log.getCarbsG(), log.getClientUuid());
    }

    private static FastApiPatientSummaryRequest.Activity activity(ActivityLog log) {
        return new FastApiPatientSummaryRequest.Activity(log.getId(), log.getPatientId(), log.getStartedAt(),
                log.getDurationMinutes(), log.getClientUuid());
    }
}

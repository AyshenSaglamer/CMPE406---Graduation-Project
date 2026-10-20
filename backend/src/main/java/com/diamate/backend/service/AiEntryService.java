package com.diamate.backend.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.function.ToLongFunction;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.ActivityLogRequest;
import com.diamate.backend.api.dto.request.AiEntriesRequest;
import com.diamate.backend.api.dto.request.AiEntriesRequest.Entry;
import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.request.InsulinLogRequest;
import com.diamate.backend.api.dto.request.MealLogRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.AiEntriesResponse;
import com.diamate.backend.api.dto.response.AiEntriesResponse.Saved;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.InsulinLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.entity.MealType;
import com.diamate.backend.exception.InvalidFieldException;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;

/**
 * Saves the AI assistant's entries once the patient has confirmed them in the app. /ai/parse itself saves nothing;
 * this is the only way an assistant result becomes health data, and it needs the patient's own request.
 *
 * Each entry becomes the matching log (glucose, insulin, meal, activity) with source AI_ASSISTANT, through the same
 * services and rules as the log endpoints (validation, no future times, clientUuid, glucose alerts). One transaction:
 * if one entry is invalid, none is saved, and the error names the entry ("entries[1].value").
 */
@Service
public class AiEntryService {

    private static final Set<String> GLUCOSE_UNITS = Set.of("mg/dl");
    private static final Set<String> INSULIN_UNITS = Set.of("units", "unit", "u", "iu");
    private static final Set<String> MEAL_UNITS = Set.of("grams", "gram", "g");
    // Activity units the assistant returns. A duration becomes durationMinutes; a distance or a count has no duration,
    // so it is kept in the notes ("5 km") instead of being guessed.
    private static final Set<String> DURATION_UNITS = Set.of("minutes", "hours", "seconds");
    // A distance or a count is only kept in the notes, so no log rule checks it: these are the limits for it.
    private static final Map<String, BigDecimal> AMOUNT_LIMITS = Map.of(
            "km", BigDecimal.valueOf(1000), "miles", BigDecimal.valueOf(1000),
            "meters", BigDecimal.valueOf(100000), "repetitions", BigDecimal.valueOf(10000));
    private static final BigDecimal SIXTY = BigDecimal.valueOf(60);
    private static final String ACTIVITY_UNITS = "minutes, hours, seconds, km, miles, meters, repetitions";

    private final GlucoseLogService glucoseLogService;
    private final InsulinLogService insulinLogService;
    private final MealLogService mealLogService;
    private final ActivityLogService activityLogService;
    private final HealthDataAccess access;
    private final Validator validator;
    private final Clock clock;

    public AiEntryService(GlucoseLogService glucoseLogService, InsulinLogService insulinLogService,
            MealLogService mealLogService, ActivityLogService activityLogService, HealthDataAccess access,
            Validator validator, Clock clock) {
        this.glucoseLogService = glucoseLogService;
        this.insulinLogService = insulinLogService;
        this.mealLogService = mealLogService;
        this.activityLogService = activityLogService;
        this.access = access;
        this.validator = validator;
        this.clock = clock;
    }

    @Transactional
    public AiEntriesResponse save(long viewerId, long patientId, AiEntriesRequest request) {
        access.checkCanWrite(viewerId, patientId); // only the patient, like every log endpoint
        Instant now = clock.instant();
        List<Saved> saved = new ArrayList<>();
        for (int i = 0; i < request.entries().size(); i++) {
            try {
                saved.add(save(viewerId, patientId, request.entries().get(i), now));
            } catch (InvalidFieldException e) {
                // Thrown on, so the whole transaction is rolled back; the field now says which entry it was.
                throw new InvalidFieldException("entries[" + i + "]." + entryField(e.getField()), e.getMessage());
            }
        }
        return new AiEntriesResponse(saved.size(), saved);
    }

    private Saved save(long viewerId, long patientId, Entry entry, Instant now) {
        Instant at = entry.at() != null ? entry.at() : now;
        return switch (entry.intent()) {
            case LOG_GLUCOSE -> {
                requireUnit(entry, GLUCOSE_UNITS, "Glucose must be in mg/dL");
                GlucoseLogRequest log = valid(new GlucoseLogRequest(wholeMgdl(entry.value()), at, entry.mealContext(),
                        null, EntrySource.AI_ASSISTANT, entry.clientUuid()));
                yield saved(entry, glucoseLogService.create(viewerId, patientId, log), GlucoseLogResponse::id);
            }
            case LOG_INSULIN -> {
                requireUnit(entry, INSULIN_UNITS, "Insulin must be in units");
                InsulinLogRequest log = valid(new InsulinLogRequest(entry.value(), null, null, null, at, null, null,
                        EntrySource.AI_ASSISTANT, entry.clientUuid()));
                yield saved(entry, insulinLogService.create(viewerId, patientId, log), InsulinLogResponse::id);
            }
            case LOG_MEAL -> {
                requireUnit(entry, MEAL_UNITS, "Carbohydrates must be in grams");
                MealType mealType = entry.mealType() != null ? entry.mealType() : MealType.OTHER;
                MealLogRequest log = valid(new MealLogRequest(mealType, at, null, entry.value(), null, null, null,
                        null, EntrySource.AI_ASSISTANT, entry.clientUuid()));
                yield saved(entry, mealLogService.create(viewerId, patientId, log), MealLogResponse::id);
            }
            case LOG_ACTIVITY -> {
                String unit = entry.unit() == null ? "" : entry.unit().trim().toLowerCase(Locale.ROOT);
                BigDecimal duration = null;
                String notes = null;
                if (DURATION_UNITS.contains(unit)) {
                    duration = switch (unit) {
                        case "hours" -> entry.value().multiply(SIXTY).setScale(1, RoundingMode.HALF_UP);
                        case "seconds" -> entry.value().divide(SIXTY, 1, RoundingMode.HALF_UP);
                        default -> entry.value(); // minutes, as the patient said it
                    };
                } else if (AMOUNT_LIMITS.containsKey(unit)) {
                    if (entry.value().compareTo(AMOUNT_LIMITS.get(unit)) > 0) {
                        throw new InvalidFieldException("value",
                                "Must be at most " + AMOUNT_LIMITS.get(unit).toPlainString() + " " + unit);
                    }
                    notes = entry.value().stripTrailingZeros().toPlainString() + " " + unit;
                } else {
                    throw new InvalidFieldException("unit", "Must be one of: " + ACTIVITY_UNITS);
                }
                ActivityLogRequest log = valid(new ActivityLogRequest(entry.activity(), at, duration, null, null, null,
                        null, notes, EntrySource.AI_ASSISTANT, entry.clientUuid()));
                yield saved(entry, activityLogService.create(viewerId, patientId, log), ActivityLogResponse::id);
            }
        };
    }

    private static <T> Saved saved(Entry entry, CreateResult<T> result, ToLongFunction<T> id) {
        return new Saved(entry.intent(), id.applyAsLong(result.log()), result.created(), result.log());
    }

    /** Empty unit = the usual one. Compared without case, so "mg/dL" and "MG/DL" are the same. */
    private static void requireUnit(Entry entry, Set<String> allowed, String message) {
        if (entry.unit() != null && !entry.unit().isBlank()
                && !allowed.contains(entry.unit().trim().toLowerCase(Locale.ROOT))) {
            throw new InvalidFieldException("unit", message);
        }
    }

    /** The assistant returns numbers like 125.0; glucose is stored in whole mg/dL, so 125.5 is refused, not rounded. */
    private static Integer wholeMgdl(BigDecimal value) {
        BigDecimal whole = value.stripTrailingZeros();
        if (whole.scale() > 0 || whole.compareTo(BigDecimal.valueOf(Integer.MAX_VALUE)) > 0) {
            throw new InvalidFieldException("value", "Glucose must be a whole number of mg/dL");
        }
        return whole.intValueExact();
    }

    /** The log request's own rules (@Valid on the log endpoints); the first broken rule is reported. */
    private <T> T valid(T request) {
        validator.validate(request).stream()
                .min(Comparator.comparing((ConstraintViolation<T> v) -> v.getPropertyPath().toString()))
                .ifPresent(v -> {
                    throw new InvalidFieldException(v.getPropertyPath().toString(), v.getMessage());
                });
        return request;
    }

    /** The entry field a log field came from, so the app can show the error next to the right input. */
    private static String entryField(String logField) {
        return switch (logField) {
            case "glucoseValue", "doseUnits", "carbsG", "durationMinutes", "notes" -> "value"; // notes: "5 km"
            case "measurementTime", "administeredAt", "eatenAt", "startedAt" -> "at";
            case "activityType" -> "activity";
            default -> logField;
        };
    }
}

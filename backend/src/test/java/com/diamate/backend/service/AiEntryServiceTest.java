package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.diamate.backend.api.dto.request.ActivityLogRequest;
import com.diamate.backend.api.dto.request.AiEntriesRequest;
import com.diamate.backend.api.dto.request.AiEntriesRequest.Entry;
import com.diamate.backend.api.dto.request.AiIntent;
import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.request.InsulinLogRequest;
import com.diamate.backend.api.dto.request.MealLogRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.AiEntriesResponse;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.InsulinLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.entity.ActivitySource;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.InsulinSource;
import com.diamate.backend.entity.MealContext;
import com.diamate.backend.entity.MealSource;
import com.diamate.backend.entity.MealType;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.PatientAccessRepository;

import jakarta.validation.Validation;

/**
 * How an entry of the AI assistant becomes a log: units, defaults, the source and which entry an error belongs to.
 * The log services are mocks (their own rules are tested in their tests); the validation rules are the real ones.
 */
@ExtendWith(MockitoExtension.class)
class AiEntryServiceTest {

    private static final long PATIENT = 5;
    private static final Instant NOW = Instant.parse("2026-10-13T09:00:00Z");
    private static final Instant BREAKFAST = Instant.parse("2026-10-13T07:30:00Z");
    private static final UUID UUID_1 = UUID.fromString("3f1c2a9e-8d7b-4c6a-9e5f-1a2b3c4d5e6f");

    @Mock
    private GlucoseLogService glucoseLogService;

    @Mock
    private InsulinLogService insulinLogService;

    @Mock
    private MealLogService mealLogService;

    @Mock
    private ActivityLogService activityLogService;

    @Mock
    private PatientAccessRepository patientAccessRepository;

    @Mock
    private AuditService auditService;

    private AiEntryService service;

    @BeforeEach
    void setUp() {
        service = new AiEntryService(glucoseLogService, insulinLogService, mealLogService, activityLogService,
                new HealthDataAccess(patientAccessRepository, auditService),
                Validation.buildDefaultValidatorFactory().getValidator(), Clock.fixed(NOW, ZoneOffset.UTC));
    }

    // ---------- each intent ----------

    @Test
    void glucoseEntryBecomesAWholeNumberReadingFromTheAssistant() {
        when(glucoseLogService.create(eq(PATIENT), eq(PATIENT), any())).thenReturn(CreateResult.created(glucose(1L)));

        AiEntriesResponse response = service.save(PATIENT, PATIENT, request(new Entry(AiIntent.LOG_GLUCOSE,
                new BigDecimal("125.0"), "mg/dL", null, null, null, MealContext.FASTING, UUID_1)));

        ArgumentCaptor<GlucoseLogRequest> saved = ArgumentCaptor.forClass(GlucoseLogRequest.class);
        verify(glucoseLogService).create(eq(PATIENT), eq(PATIENT), saved.capture());
        assertThat(saved.getValue().glucoseValue()).isEqualTo(125); // the assistant says 125.0
        assertThat(saved.getValue().measurementTime()).isEqualTo(NOW); // no time given: now
        assertThat(saved.getValue().mealContext()).isEqualTo(MealContext.FASTING);
        assertThat(saved.getValue().source()).isEqualTo(EntrySource.AI_ASSISTANT);
        assertThat(saved.getValue().clientUuid()).isEqualTo(UUID_1);
        assertThat(response.savedCount()).isEqualTo(1);
        assertThat(response.saved().get(0).intent()).isEqualTo(AiIntent.LOG_GLUCOSE);
        assertThat(response.saved().get(0).id()).isEqualTo(1L);
        assertThat(response.saved().get(0).created()).isTrue();
    }

    @Test
    void insulinAndMealUseTheirUnitsTheGivenTimeAndDefaults() {
        when(insulinLogService.create(eq(PATIENT), eq(PATIENT), any())).thenReturn(CreateResult.created(insulin(2L)));
        when(mealLogService.create(eq(PATIENT), eq(PATIENT), any())).thenReturn(CreateResult.created(meal(3L)));

        service.save(PATIENT, PATIENT, request(
                new Entry(AiIntent.LOG_INSULIN, new BigDecimal("6.5"), "units", null, BREAKFAST, null, null, null),
                new Entry(AiIntent.LOG_MEAL, new BigDecimal("45"), "grams", null, BREAKFAST, null, null, null)));

        ArgumentCaptor<InsulinLogRequest> dose = ArgumentCaptor.forClass(InsulinLogRequest.class);
        verify(insulinLogService).create(eq(PATIENT), eq(PATIENT), dose.capture());
        assertThat(dose.getValue().doseUnits()).isEqualByComparingTo("6.5");
        assertThat(dose.getValue().administeredAt()).isEqualTo(BREAKFAST);
        assertThat(dose.getValue().source()).isEqualTo(EntrySource.AI_ASSISTANT);
        ArgumentCaptor<MealLogRequest> meal = ArgumentCaptor.forClass(MealLogRequest.class);
        verify(mealLogService).create(eq(PATIENT), eq(PATIENT), meal.capture());
        assertThat(meal.getValue().carbsG()).isEqualByComparingTo("45");
        assertThat(meal.getValue().mealType()).isEqualTo(MealType.OTHER); // the assistant does not say which meal
        assertThat(meal.getValue().source()).isEqualTo(EntrySource.AI_ASSISTANT);
    }

    @Test
    void activityHoursAndSecondsBecomeMinutes() {
        when(activityLogService.create(eq(PATIENT), eq(PATIENT), any())).thenReturn(CreateResult.created(activity(4L)));

        service.save(PATIENT, PATIENT, request(
                new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("1.5"), "hours", "walked", null, null, null, null),
                new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("90"), "seconds", "plank", null, null, null, null),
                new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("30.0"), "Minutes", "running", null, null, null, null)));

        ArgumentCaptor<ActivityLogRequest> saved = ArgumentCaptor.forClass(ActivityLogRequest.class);
        verify(activityLogService, times(3)).create(eq(PATIENT), eq(PATIENT), saved.capture());
        assertThat(saved.getAllValues()).extracting(ActivityLogRequest::durationMinutes)
                .usingElementComparator(BigDecimal::compareTo)
                .containsExactly(new BigDecimal("90"), new BigDecimal("1.5"), new BigDecimal("30"));
        assertThat(saved.getAllValues()).extracting(ActivityLogRequest::activityType)
                .containsExactly("walked", "plank", "running");
        assertThat(saved.getAllValues()).extracting(ActivityLogRequest::source).containsOnly(EntrySource.AI_ASSISTANT);
    }

    @Test
    void aDistanceOrACountIsKeptInTheNotesWithoutAGuessedDuration() {
        when(activityLogService.create(eq(PATIENT), eq(PATIENT), any())).thenReturn(CreateResult.created(activity(4L)));

        service.save(PATIENT, PATIENT, request(
                new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("5.0"), "km", "ran", null, null, null, null),
                new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("20"), "repetitions", "squats", null, null, null, null)));

        ArgumentCaptor<ActivityLogRequest> saved = ArgumentCaptor.forClass(ActivityLogRequest.class);
        verify(activityLogService, times(2)).create(eq(PATIENT), eq(PATIENT), saved.capture());
        assertThat(saved.getAllValues()).extracting(ActivityLogRequest::durationMinutes).containsOnlyNulls();
        assertThat(saved.getAllValues()).extracting(ActivityLogRequest::notes).containsExactly("5 km", "20 repetitions");
    }

    @Test
    void aResentEntryIsReportedAsNotCreated() {
        when(glucoseLogService.create(eq(PATIENT), eq(PATIENT), any())).thenReturn(CreateResult.existing(glucose(1L)));

        AiEntriesResponse response = service.save(PATIENT, PATIENT, request(new Entry(AiIntent.LOG_GLUCOSE,
                new BigDecimal("125"), null, null, null, null, null, UUID_1)));

        assertThat(response.saved().get(0).created()).isFalse();
    }

    // ---------- errors name the entry ----------

    @Test
    void glucoseMustBeAWholeNumberOfMgdl() {
        assertThatThrownBy(() -> service.save(PATIENT, PATIENT, request(new Entry(AiIntent.LOG_GLUCOSE,
                new BigDecimal("125.5"), "mg/dL", null, null, null, null, null))))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Glucose must be a whole number of mg/dL")
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("entries[0].value"));
        verifyNoInteractions(glucoseLogService);
    }

    @Test
    void theLogRulesApplyAndTheErrorNamesTheEntry() {
        // The glucose entry is fine; the second one breaks the insulin limit of the log endpoints (at most 300 units).
        when(glucoseLogService.create(eq(PATIENT), eq(PATIENT), any())).thenReturn(CreateResult.created(glucose(1L)));

        assertThatThrownBy(() -> service.save(PATIENT, PATIENT, request(
                new Entry(AiIntent.LOG_GLUCOSE, new BigDecimal("140"), null, null, null, null, null, null),
                new Entry(AiIntent.LOG_INSULIN, new BigDecimal("400"), "units", null, null, null, null, null))))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Dose must be at most 300 units")
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("entries[1].value"));
        verifyNoInteractions(insulinLogService); // and the transaction rolls back the glucose reading (tested end to end)
    }

    @Test
    void aRuleCheckedInTheLogServiceIsMappedToTheEntryField() {
        when(mealLogService.create(eq(PATIENT), eq(PATIENT), any()))
                .thenThrow(new InvalidFieldException("eatenAt", "Time must not be in the future"));

        assertThatThrownBy(() -> service.save(PATIENT, PATIENT, request(new Entry(AiIntent.LOG_MEAL,
                new BigDecimal("30"), null, null, NOW.plusSeconds(3600), MealType.SNACK, null, null))))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Time must not be in the future")
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("entries[0].at"));
    }

    @Test
    void unitsThatDoNotFitAreRefused() {
        assertField(new Entry(AiIntent.LOG_GLUCOSE, new BigDecimal("7"), "mmol/L", null, null, null, null, null),
                "entries[0].unit", "Glucose must be in mg/dL");
        assertField(new Entry(AiIntent.LOG_INSULIN, new BigDecimal("6"), "ml", null, null, null, null, null),
                "entries[0].unit", "Insulin must be in units");
        assertField(new Entry(AiIntent.LOG_MEAL, new BigDecimal("40"), "kcal", null, null, null, null, null),
                "entries[0].unit", "Carbohydrates must be in grams");
        // "unspecified": the assistant found a number but no unit ("I walked 30"); the app must ask which one.
        assertField(new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("30"), "unspecified", "walked", null, null, null, null),
                "entries[0].unit", "Must be one of: minutes, hours, seconds, km, miles, meters, repetitions");
        assertField(new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("30"), null, "walked", null, null, null, null),
                "entries[0].unit", "Must be one of: minutes, hours, seconds, km, miles, meters, repetitions");
        verifyNoInteractions(glucoseLogService, insulinLogService, mealLogService, activityLogService);
    }

    @Test
    void aDistanceOrCountAboveItsLimitIsRefusedOnTheValue() {
        // These go into the notes, where no log rule checks them, so the conversion has its own limits.
        assertField(new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("1001"), "km", "ran", null, null, null, null),
                "entries[0].value", "Must be at most 1000 km");
        assertField(new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("10001"), "repetitions", "squats", null, null, null, null),
                "entries[0].value", "Must be at most 10000 repetitions");
        verifyNoInteractions(activityLogService);
    }

    @Test
    void anActivityNeedsTheActivityWord() {
        assertField(new Entry(AiIntent.LOG_ACTIVITY, new BigDecimal("30"), "minutes", null, null, null, null, null),
                "entries[0].activity", "Activity type is required");
    }

    @Test
    void onlyThePatientCanSaveTheirEntries() {
        assertThatThrownBy(() -> service.save(PATIENT, 8L, request(new Entry(AiIntent.LOG_GLUCOSE,
                new BigDecimal("125"), null, null, null, null, null, null))))
                .isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(glucoseLogService);
    }

    // ---------- helpers ----------

    private void assertField(Entry entry, String field, String message) {
        assertThatThrownBy(() -> service.save(PATIENT, PATIENT, request(entry)))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage(message)
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo(field));
    }

    private static AiEntriesRequest request(Entry... entries) {
        return new AiEntriesRequest(List.of(entries));
    }

    private static GlucoseLogResponse glucose(long id) {
        return new GlucoseLogResponse(id, PATIENT, 125, NOW, null, GlucoseSource.AI_ASSISTANT, null, null, NOW, NOW);
    }

    private static InsulinLogResponse insulin(long id) {
        return new InsulinLogResponse(id, PATIENT, new BigDecimal("6.5"), null, null, null, NOW, null,
                InsulinSource.AI_ASSISTANT, null, null, NOW, NOW);
    }

    private static MealLogResponse meal(long id) {
        return new MealLogResponse(id, PATIENT, MealType.OTHER, NOW, null, new BigDecimal("45"), null, null, null,
                MealSource.AI_ASSISTANT, null, null, NOW, NOW);
    }

    private static ActivityLogResponse activity(long id) {
        return new ActivityLogResponse(id, PATIENT, "walked", NOW, new BigDecimal("90"), null, null, null, null,
                ActivitySource.AI_ASSISTANT, null, null, NOW, NOW);
    }
}

package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.ai.AiClient;
import com.diamate.backend.ai.FastApiParseResult;
import com.diamate.backend.ai.FastApiPatientSummaryRequest;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.entity.ActivityIntensity;
import com.diamate.backend.entity.ActivityLog;
import com.diamate.backend.entity.ActivitySource;
import com.diamate.backend.entity.GlucoseLog;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.MealLog;
import com.diamate.backend.entity.MealSource;
import com.diamate.backend.entity.MealType;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.ActivityLogRepository;
import com.diamate.backend.repository.GlucoseLogRepository;
import com.diamate.backend.repository.MealLogRepository;
import com.diamate.backend.repository.PatientAccessRepository;

@ExtendWith(MockitoExtension.class)
class AiServiceTest {

    private static final long PATIENT = 5;
    private static final long CAREGIVER = 4;
    private static final Instant NOW = Instant.parse("2026-10-05T10:00:00Z");

    @Mock
    private AiClient aiClient;

    @Mock
    private GlucoseLogRepository glucoseRepository;

    @Mock
    private MealLogRepository mealRepository;

    @Mock
    private ActivityLogRepository activityRepository;

    @Mock
    private PatientAccessRepository patientAccessRepository;

    @Mock
    private AuditService auditService;

    private AiService service;

    @BeforeEach
    void setUp() {
        service = new AiService(aiClient, new HealthDataAccess(patientAccessRepository, auditService),
                glucoseRepository, mealRepository, activityRepository, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void entriesOfTheAiServiceArePassedOnAndTheTextIsTrimmed() {
        when(aiClient.parseMultiple("glucose 130 and 6 units of insulin")).thenReturn(new FastApiParseResult("SUCCESS",
                List.of(new FastApiParseResult.Entry("LOG_GLUCOSE", "SUCCESS", 130.0, "mg/dL", null, null),
                        new FastApiParseResult.Entry("LOG_INSULIN", "SUCCESS", 6.0, "units", null, null)),
                null));

        AiParseResponse response = service.parse("  glucose 130 and 6 units of insulin ");

        assertThat(response.status()).isEqualTo("SUCCESS");
        assertThat(response.resultCount()).isEqualTo(2);
        assertThat(response.results()).extracting(AiParseResponse.Entry::intent)
                .containsExactly("LOG_GLUCOSE", "LOG_INSULIN");
    }

    @Test
    void nothingUnderstoodIsAnEmptyList() {
        when(aiClient.parseMultiple("hello")).thenReturn(
                new FastApiParseResult("UNKNOWN", null, "I could not understand the input."));

        AiParseResponse response = service.parse("hello");

        assertThat(response.status()).isEqualTo("UNKNOWN");
        assertThat(response.results()).isEmpty();
        assertThat(response.message()).isEqualTo("I could not understand the input.");
    }

    // ---------- patient summary ----------

    @Test
    void summarySendsTheLast14DaysAndLeavesOutMealsWithoutCarbsAndActivitiesWithoutDuration() {
        allow(PATIENT, "glucose", "meals", "activity", "reports");
        when(glucoseRepository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(page(glucose(1, 140), glucose(2, 180)));
        when(mealRepository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(page(meal(10, new BigDecimal("45")), meal(11, null)));
        when(activityRepository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(page(activity(20, new BigDecimal("30")), activity(21, null)));
        when(aiClient.patientSummary(any())).thenReturn(Map.of("status", "SUCCESS"));

        Map<String, Object> summary = service.patientSummary(PATIENT, PATIENT, null, null, 70, 180);

        assertThat(summary).containsEntry("status", "SUCCESS");
        ArgumentCaptor<FastApiPatientSummaryRequest> sent = ArgumentCaptor.forClass(FastApiPatientSummaryRequest.class);
        verify(aiClient).patientSummary(sent.capture());
        assertThat(sent.getValue().glucoseLogs()).extracting(FastApiPatientSummaryRequest.Glucose::glucoseValue)
                .containsExactly(140, 180);
        assertThat(sent.getValue().mealLogs()).extracting(FastApiPatientSummaryRequest.Meal::id).containsExactly(10L);
        assertThat(sent.getValue().activityLogs()).extracting(FastApiPatientSummaryRequest.Activity::id)
                .containsExactly(20L);
        assertThat(sent.getValue().rangeLow()).isEqualTo(70);
        assertThat(sent.getValue().rangeHigh()).isEqualTo(180);
        // Default window of the log lists: 14 days up to now (+ 5 minutes clock tolerance), one bounded page.
        ArgumentCaptor<Instant> from = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> to = ArgumentCaptor.forClass(Instant.class);
        verify(glucoseRepository).findInRange(eq(PATIENT), from.capture(), to.capture(),
                eq(PageRequest.of(0, AiService.MAX_SUMMARY_RECORDS)));
        assertThat(Duration.between(from.getValue(), to.getValue())).isEqualTo(Duration.ofDays(14));
    }

    @Test
    void careTeamMemberWithoutMealsAndActivityPermissionGetsAGlucoseOnlySummary() {
        // Like the demo caregiver and patient08: glucose (and reports) are shared, meals and activity are not.
        allow(CAREGIVER, "glucose", "reports");
        when(glucoseRepository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(page(glucose(1, 140), glucose(2, 180)));
        when(aiClient.patientSummary(any())).thenReturn(Map.of("status", "SUCCESS"));

        service.patientSummary(CAREGIVER, PATIENT, null, null, 70, 180);

        ArgumentCaptor<FastApiPatientSummaryRequest> sent = ArgumentCaptor.forClass(FastApiPatientSummaryRequest.class);
        verify(aiClient).patientSummary(sent.capture());
        assertThat(sent.getValue().mealLogs()).isEmpty();
        assertThat(sent.getValue().activityLogs()).isEmpty();
        verifyNoInteractions(mealRepository, activityRepository);
        // One audit row per data type the caregiver tried to read, allowed or not.
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.REPORTS, true);
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.GLUCOSE_LOGS, true);
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.MEAL_LOGS, false);
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.ACTIVITY_LOGS, false);
    }

    @Test
    void withoutTheReportsPermissionThePatientIsNotFoundEvenWithGlucose() {
        // The patient shares the glucose logs but turned "reports" off: the AI analysis of them is not shared.
        allow(CAREGIVER, "glucose", "meals", "activity");

        assertThatThrownBy(() -> service.patientSummary(CAREGIVER, PATIENT, null, null, 70, 180))
                .isInstanceOf(ResourceNotFoundException.class);

        verifyNoInteractions(glucoseRepository, mealRepository, activityRepository, aiClient);
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.REPORTS, false);
    }

    @Test
    void withoutTheGlucosePermissionThePatientIsNotFound() {
        allow(CAREGIVER, "reports");
        assertThatThrownBy(() -> service.patientSummary(CAREGIVER, PATIENT, null, null, 70, 180))
                .isInstanceOf(ResourceNotFoundException.class);

        verifyNoInteractions(glucoseRepository, aiClient);
    }

    @Test
    void fewerThanTwoGlucoseReadingsIsA400AndTheAiServiceIsNotCalled() {
        allow(PATIENT, "glucose", "reports");
        when(glucoseRepository.findInRange(eq(PATIENT), any(), any(), any())).thenReturn(page(glucose(1, 140)));

        assertThatThrownBy(() -> service.patientSummary(PATIENT, PATIENT, null, null, 70, 180))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessageContaining("At least 2 glucose readings");

        verify(aiClient, never()).patientSummary(any());
    }

    @Test
    void aRangeOfMoreThan31DaysIsA400() {
        allow(PATIENT, "glucose", "reports");

        assertThatThrownBy(() -> service.patientSummary(PATIENT, PATIENT, NOW.minus(Duration.ofDays(32)), NOW, 70, 180))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("A summary covers at most 31 days");

        verifyNoInteractions(glucoseRepository, aiClient);
    }

    @Test
    void moreRecordsThanFitInOneRequestIsA400() {
        allow(PATIENT, "glucose", "reports");
        when(glucoseRepository.findInRange(eq(PATIENT), any(), any(), any())).thenReturn(
                new PageImpl<>(List.of(glucose(1, 140), glucose(2, 150)), PageRequest.of(0, 2), 3));

        assertThatThrownBy(() -> service.patientSummary(PATIENT, PATIENT, null, null, 70, 180))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessageContaining("Too many records");

        verify(aiClient, never()).patientSummary(any());
    }

    @Test
    void targetRangeIsCheckedBeforeAnythingIsLoaded() {
        allow(PATIENT, "glucose", "reports");

        assertThatThrownBy(() -> service.patientSummary(PATIENT, PATIENT, null, null, 180, 70))
                .isInstanceOf(InvalidFieldException.class).hasMessage("rangeLow must be lower than rangeHigh");
        assertThatThrownBy(() -> service.patientSummary(PATIENT, PATIENT, null, null, 0, 180))
                .isInstanceOf(InvalidFieldException.class).hasMessage("rangeLow must be between 10 and 600 mg/dL");
        assertThatThrownBy(() -> service.patientSummary(PATIENT, PATIENT, null, null, 70, Double.NaN))
                .isInstanceOf(InvalidFieldException.class).hasMessage("rangeHigh must be between 10 and 600 mg/dL");

        verifyNoInteractions(glucoseRepository, aiClient);
    }

    // ---------- helpers ----------

    /** viewer may see these permissions of PATIENT (fn_can_access), nothing else. */
    private void allow(long viewer, String... permissions) {
        when(patientAccessRepository.canAccess(anyLong(), anyLong(), any())).thenAnswer(call -> (long) call
                .getArgument(0) == viewer && (long) call.getArgument(1) == PATIENT
                && List.of(permissions).contains(call.getArgument(2)));
    }

    @SafeVarargs
    private static <T> PageImpl<T> page(T... logs) {
        return new PageImpl<>(List.of(logs), PageRequest.of(0, AiService.MAX_SUMMARY_RECORDS), logs.length);
    }

    private static GlucoseLog glucose(long id, int value) {
        GlucoseLog log = new GlucoseLog(PATIENT, null, GlucoseSource.MANUAL, PATIENT);
        log.update(value, NOW.minus(Duration.ofHours(id)), null, null);
        return withId(log, id);
    }

    private static MealLog meal(long id, BigDecimal carbs) {
        MealLog log = new MealLog(PATIENT, null, MealSource.MANUAL);
        log.update(MealType.BREAKFAST, NOW.minus(Duration.ofHours(3)), "oatmeal", carbs, null, null, null, null);
        return withId(log, id);
    }

    private static ActivityLog activity(long id, BigDecimal minutes) {
        ActivityLog log = new ActivityLog(PATIENT, null, ActivitySource.MANUAL);
        log.update("walking", NOW.minus(Duration.ofHours(2)), minutes, null, null, null, ActivityIntensity.LOW, null);
        return withId(log, id);
    }

    private static <T> T withId(T log, long id) {
        ReflectionTestUtils.setField(log, "id", id);
        return log;
    }
}

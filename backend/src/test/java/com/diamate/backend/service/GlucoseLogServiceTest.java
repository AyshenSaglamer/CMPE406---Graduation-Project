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

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.GlucoseLog;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.MealContext;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.GlucoseLogRepository;
import com.diamate.backend.repository.PatientAccessRepository;

/**
 * GlucoseLogService with the real HealthDataAccess; only the repositories and the alert service are mocks.
 * The other three log services follow the same pattern, so their tests only cover what differs.
 */
@ExtendWith(MockitoExtension.class)
class GlucoseLogServiceTest {

    private static final long PATIENT = 5;
    private static final long OTHER_PATIENT = 6;
    private static final long CLINICIAN = 2;
    private static final Instant NOW = Instant.parse("2026-10-05T10:00:00Z");
    private static final Instant EARLIER = Instant.parse("2026-10-05T08:30:00Z");

    @Mock
    private GlucoseLogRepository repository;

    @Mock
    private PatientAccessRepository patientAccessRepository;

    @Mock
    private GlucoseAlertService alertService;

    private GlucoseLogService service;

    @BeforeEach
    void setUp() {
        service = new GlucoseLogService(repository, new HealthDataAccess(patientAccessRepository), alertService,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    // ---------- create ----------

    @Test
    void patientCreatesOwnLogAndTheReadingIsCheckedForAlerts() {
        when(repository.saveAndFlush(any(GlucoseLog.class))).thenAnswer(invocation -> withId(invocation.getArgument(0), 100L));

        CreateResult<GlucoseLogResponse> result = service.create(PATIENT, PATIENT,
                new GlucoseLogRequest(54, EARLIER, MealContext.FASTING, "  before breakfast ", null, null));

        assertThat(result.created()).isTrue();
        assertThat(result.log().id()).isEqualTo(100L);
        assertThat(result.log().glucoseValue()).isEqualTo(54);
        assertThat(result.log().source()).isEqualTo(GlucoseSource.MANUAL);
        assertThat(result.log().notes()).isEqualTo("before breakfast");

        ArgumentCaptor<GlucoseLog> saved = ArgumentCaptor.forClass(GlucoseLog.class);
        verify(repository).saveAndFlush(saved.capture());
        assertThat(saved.getValue().getPatientId()).isEqualTo(PATIENT);
        assertThat(saved.getValue().getEnteredBy()).isEqualTo(PATIENT);
        verify(alertService).checkReading(saved.getValue());
    }

    @Test
    void aiAssistantSourceIsKept() {
        when(repository.saveAndFlush(any(GlucoseLog.class))).thenAnswer(invocation -> withId(invocation.getArgument(0), 101L));

        CreateResult<GlucoseLogResponse> result = service.create(PATIENT, PATIENT,
                new GlucoseLogRequest(125, EARLIER, null, null, EntrySource.AI_ASSISTANT, null));

        assertThat(result.log().source()).isEqualTo(GlucoseSource.AI_ASSISTANT);
    }

    @Test
    void resentRequestWithTheSameClientUuidReturnsTheExistingLogAndSavesNothing() {
        UUID clientUuid = UUID.randomUUID();
        GlucoseLog existing = log(100L, PATIENT, 120);
        when(repository.findByPatientIdAndClientUuid(PATIENT, clientUuid)).thenReturn(Optional.of(existing));

        CreateResult<GlucoseLogResponse> result = service.create(PATIENT, PATIENT,
                new GlucoseLogRequest(120, EARLIER, null, null, null, clientUuid));

        assertThat(result.created()).isFalse();
        assertThat(result.log().id()).isEqualTo(100L);
        verify(repository, never()).saveAndFlush(any());
        verifyNoInteractions(alertService); // no second alert for the same reading
    }

    @Test
    void clientUuidOfADeletedLogIsAConflict() {
        UUID clientUuid = UUID.randomUUID();
        when(repository.findByPatientIdAndClientUuid(PATIENT, clientUuid)).thenReturn(Optional.empty());
        when(repository.saveAndFlush(any(GlucoseLog.class)))
                .thenThrow(new DataIntegrityViolationException("ux_glucose_logs_client"));

        assertThatThrownBy(() -> service.create(PATIENT, PATIENT,
                new GlucoseLogRequest(120, EARLIER, null, null, null, clientUuid)))
                .isInstanceOf(ResourceConflictException.class);
        verifyNoInteractions(alertService);
    }

    @Test
    void aPatientCannotWriteIntoAnotherPatientsLogs() {
        assertThatThrownBy(() -> service.create(PATIENT, OTHER_PATIENT,
                new GlucoseLogRequest(120, EARLIER, null, null, null, null)))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Patient not found");
        verifyNoInteractions(repository, alertService);
    }

    @Test
    void measurementTimeInTheFutureIsRejected() {
        assertThatThrownBy(() -> service.create(PATIENT, PATIENT,
                new GlucoseLogRequest(120, NOW.plusSeconds(3600), null, null, null, null)))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Time must not be in the future");
        verifyNoInteractions(repository);
    }

    // ---------- read ----------

    @Test
    void readingWithoutAccessIs404AndNothingIsQueried() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "glucose")).thenReturn(false);

        assertThatThrownBy(() -> service.list(CLINICIAN, PATIENT, null, null, 0, 50))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.get(CLINICIAN, PATIENT, 100L))
                .isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(repository);
    }

    @Test
    void clinicianWithAccessGetsAPageOfTheLast14Days() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "glucose")).thenReturn(true);
        when(repository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(log(100L, PATIENT, 140)), PageRequest.of(0, 50), 1));

        PageResponse<GlucoseLogResponse> page = service.list(CLINICIAN, PATIENT, null, null, 0, 50);

        assertThat(page.items()).extracting(GlucoseLogResponse::glucoseValue).containsExactly(140);
        assertThat(page.totalElements()).isEqualTo(1);
        ArgumentCaptor<Instant> from = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> to = ArgumentCaptor.forClass(Instant.class);
        verify(repository).findInRange(eq(PATIENT), from.capture(), to.capture(), any(Pageable.class));
        assertThat(to.getValue()).isEqualTo(NOW.plus(LogRules.FUTURE_TOLERANCE));
        assertThat(from.getValue()).isEqualTo(to.getValue().minus(LogRules.DEFAULT_RANGE));
    }

    @Test
    void logOfAnotherPatientIsNotFound() {
        when(patientAccessRepository.canAccess(PATIENT, PATIENT, "glucose")).thenReturn(true);
        when(repository.findByIdAndPatientId(999L, PATIENT)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get(PATIENT, PATIENT, 999L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Glucose log not found");
    }

    // ---------- update / delete ----------

    @Test
    void updateReplacesTheValuesButNotTheSource() {
        GlucoseLog existing = log(100L, PATIENT, 120);
        when(repository.findByIdAndPatientId(100L, PATIENT)).thenReturn(Optional.of(existing));
        when(repository.saveAndFlush(existing)).thenReturn(existing);

        GlucoseLogResponse updated = service.update(PATIENT, PATIENT, 100L,
                new GlucoseLogRequest(135, EARLIER, MealContext.AFTER_MEAL, "corrected", EntrySource.AI_ASSISTANT, null));

        assertThat(updated.glucoseValue()).isEqualTo(135);
        assertThat(updated.mealContext()).isEqualTo(MealContext.AFTER_MEAL);
        assertThat(updated.source()).isEqualTo(GlucoseSource.MANUAL);
        verifyNoInteractions(alertService); // edits do not create alerts
    }

    @Test
    void deleteIsASoftDelete() {
        GlucoseLog existing = log(100L, PATIENT, 120);
        when(repository.findByIdAndPatientId(100L, PATIENT)).thenReturn(Optional.of(existing));

        service.delete(PATIENT, PATIENT, 100L);

        assertThat(existing.getDeletedAt()).isEqualTo(NOW);
        verify(repository, never()).delete(any());
    }

    @Test
    void deletingAnotherPatientsLogIs404() {
        assertThatThrownBy(() -> service.delete(PATIENT, OTHER_PATIENT, 100L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).findByIdAndPatientId(anyLong(), anyLong());
    }

    // ---------- helpers ----------

    private static GlucoseLog log(long id, long patientId, int value) {
        GlucoseLog log = new GlucoseLog(patientId, null, GlucoseSource.MANUAL, patientId);
        log.update(value, EARLIER, null, null);
        return withId(log, id);
    }

    // In production the id comes from the database; here we set it the same way Hibernate would.
    private static GlucoseLog withId(GlucoseLog log, long id) {
        ReflectionTestUtils.setField(log, "id", id);
        return log;
    }
}

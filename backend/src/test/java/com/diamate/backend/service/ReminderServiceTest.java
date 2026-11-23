package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.request.ReminderEventRequest;
import com.diamate.backend.api.dto.request.ReminderRequest;
import com.diamate.backend.api.dto.response.ReminderEventResponse;
import com.diamate.backend.api.dto.response.ReminderResponse;
import com.diamate.backend.entity.Reminder;
import com.diamate.backend.entity.ReminderEvent;
import com.diamate.backend.entity.ReminderEventStatus;
import com.diamate.backend.entity.ReminderType;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.PatientAccessRepository;
import com.diamate.backend.repository.ReminderEventRepository;
import com.diamate.backend.repository.ReminderRepository;

/** ReminderService with the real HealthDataAccess; only the repositories and the audit service are mocks. */
@ExtendWith(MockitoExtension.class)
class ReminderServiceTest {

    private static final long PATIENT = 5;
    private static final long CLINICIAN = 2;
    private static final long REMINDER_ID = 60;
    private static final Instant NOW = Instant.parse("2026-11-23T10:00:00Z");

    @Mock
    private ReminderRepository repository;

    @Mock
    private ReminderEventRepository eventRepository;

    @Mock
    private PatientAccessRepository patientAccessRepository;

    @Mock
    private AuditService auditService;

    private ReminderService service;

    @BeforeEach
    void setUp() {
        service = new ReminderService(repository, eventRepository,
                new HealthDataAccess(patientAccessRepository, auditService), Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static ReminderRequest metformin() {
        return new ReminderRequest(null, "  Metformin ", "500 mg", null, LocalTime.of(8, 0, 30),
                List.of(DayOfWeek.FRIDAY, DayOfWeek.MONDAY, DayOfWeek.MONDAY), "Europe/Istanbul", null);
    }

    private Reminder saved(long id) {
        Reminder reminder = new Reminder(PATIENT);
        reminder.update(ReminderType.MEDICATION, "Metformin", "500 mg", null, LocalTime.of(8, 0), "MON,FRI",
                "Europe/Istanbul", true);
        ReflectionTestUtils.setField(reminder, "id", id);
        return reminder;
    }

    private void savesAs(long id) {
        when(repository.saveAndFlush(any(Reminder.class))).thenAnswer(call -> {
            Reminder reminder = call.getArgument(0);
            ReflectionTestUtils.setField(reminder, "id", id);
            return reminder;
        });
    }

    // ---------- create / update / delete ----------

    @Test
    void createNormalisesTheReminder() {
        savesAs(REMINDER_ID);

        ReminderResponse created = service.create(PATIENT, PATIENT, metformin());

        assertThat(created.id()).isEqualTo(REMINDER_ID);
        assertThat(created.reminderType()).isEqualTo(ReminderType.MEDICATION); // default
        assertThat(created.medicationName()).isEqualTo("Metformin"); // trimmed
        assertThat(created.scheduledTime()).isEqualTo(LocalTime.of(8, 0)); // seconds dropped
        assertThat(created.daysOfWeek()).containsExactly(DayOfWeek.MONDAY, DayOfWeek.FRIDAY); // week order, once
        assertThat(created.timezone()).isEqualTo("Europe/Istanbul");
        assertThat(created.active()).isTrue(); // default
        ArgumentCaptor<Reminder> stored = ArgumentCaptor.forClass(Reminder.class);
        verify(repository).saveAndFlush(stored.capture());
        assertThat(stored.getValue().getDaysOfWeek()).isEqualTo("MON,FRI"); // the column's format
    }

    @Test
    void missingTimezoneIsUtcAndAnOffsetIsAccepted() {
        assertThat(ReminderService.zone(null)).isEqualTo("UTC");
        assertThat(ReminderService.zone("  ")).isEqualTo("UTC");
        assertThat(ReminderService.zone("+03:00")).isEqualTo("+03:00");
        assertThatThrownBy(() -> ReminderService.zone("Mars/Olympus"))
                .isInstanceOf(InvalidFieldException.class)
                .extracting("field").isEqualTo("timezone");
    }

    @Test
    void aMedicationReminderNeedsAName() {
        ReminderRequest noName = new ReminderRequest(ReminderType.MEDICATION, " ", null, null, LocalTime.NOON,
                List.of(DayOfWeek.MONDAY), null, null);

        assertThatThrownBy(() -> service.create(PATIENT, PATIENT, noName))
                .isInstanceOf(InvalidFieldException.class)
                .extracting("field").isEqualTo("medicationName");
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    void aGlucoseCheckReminderNeedsNoMedicationName() {
        savesAs(REMINDER_ID);
        ReminderRequest check = new ReminderRequest(ReminderType.GLUCOSE_CHECK, null, null, "Before lunch",
                LocalTime.of(12, 0), List.of(DayOfWeek.SUNDAY), null, false);

        ReminderResponse created = service.create(PATIENT, PATIENT, check);

        assertThat(created.reminderType()).isEqualTo(ReminderType.GLUCOSE_CHECK);
        assertThat(created.message()).isEqualTo("Before lunch");
        assertThat(created.active()).isFalse();
    }

    @Test
    void onlyThePatientCreatesReminders() {
        assertThatThrownBy(() -> service.create(CLINICIAN, PATIENT, metformin()))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    void thereIsALimitPerPatient() {
        when(repository.countByPatientId(PATIENT)).thenReturn((long) ReminderService.MAX_REMINDERS_PER_PATIENT);

        assertThatThrownBy(() -> service.create(PATIENT, PATIENT, metformin()))
                .isInstanceOf(ResourceConflictException.class);
    }

    @Test
    void updateReplacesTheFields() {
        Reminder reminder = saved(REMINDER_ID);
        when(repository.findByIdAndPatientId(REMINDER_ID, PATIENT)).thenReturn(Optional.of(reminder));
        when(repository.saveAndFlush(reminder)).thenReturn(reminder);
        ReminderRequest evening = new ReminderRequest(ReminderType.MEDICATION, "Metformin", "1000 mg", null,
                LocalTime.of(20, 0), List.of(DayOfWeek.values()), "+03:00", false);

        ReminderResponse updated = service.update(PATIENT, PATIENT, REMINDER_ID, evening);

        assertThat(updated.dosage()).isEqualTo("1000 mg");
        assertThat(updated.scheduledTime()).isEqualTo(LocalTime.of(20, 0));
        assertThat(updated.daysOfWeek()).hasSize(7);
        assertThat(updated.active()).isFalse();
        assertThat(reminder.getDaysOfWeek()).isEqualTo("MON,TUE,WED,THU,FRI,SAT,SUN");
    }

    @Test
    void anotherPatientsReminderIsNotFound() {
        when(repository.findByIdAndPatientId(REMINDER_ID, PATIENT)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(PATIENT, PATIENT, REMINDER_ID))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage(ReminderService.NOT_FOUND);
        verify(repository, never()).delete(any());
    }

    @Test
    void deleteRemovesTheReminder() {
        Reminder reminder = saved(REMINDER_ID);
        when(repository.findByIdAndPatientId(REMINDER_ID, PATIENT)).thenReturn(Optional.of(reminder));

        service.delete(PATIENT, PATIENT, REMINDER_ID);

        verify(repository).delete(reminder);
    }

    // ---------- reading ----------

    @Test
    void patientListsOwnRemindersWithoutAudit() {
        when(patientAccessRepository.canAccess(PATIENT, PATIENT, "medications")).thenReturn(true);
        when(repository.findByPatientIdOrderByScheduledTimeAscIdAsc(PATIENT)).thenReturn(List.of(saved(1), saved(2)));

        assertThat(service.list(PATIENT, PATIENT)).extracting(ReminderResponse::id).containsExactly(1L, 2L);
        verifyNoInteractions(auditService);
    }

    @Test
    void careTeamReadsWithTheMedicationsPermissionAndIsAudited() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "medications")).thenReturn(true);
        when(repository.findByPatientIdOrderByScheduledTimeAscIdAsc(PATIENT)).thenReturn(List.of(saved(1)));

        assertThat(service.list(CLINICIAN, PATIENT)).hasSize(1);
        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.REMINDERS, true);
    }

    @Test
    void careTeamWithoutThePermissionGets404() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "medications")).thenReturn(false);

        assertThatThrownBy(() -> service.list(CLINICIAN, PATIENT)).isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).findByPatientIdOrderByScheduledTimeAscIdAsc(anyLong());
        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.REMINDERS, false);
    }

    @Test
    void eventsAreListedForTheLast14DaysByDefault() {
        when(patientAccessRepository.canAccess(eq(PATIENT), eq(PATIENT), anyString())).thenReturn(true);
        when(eventRepository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 50), 0));

        service.events(PATIENT, PATIENT, null, null, 0, 50);

        ArgumentCaptor<Instant> from = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> to = ArgumentCaptor.forClass(Instant.class);
        verify(eventRepository).findInRange(eq(PATIENT), from.capture(), to.capture(), any(Pageable.class));
        assertThat(to.getValue()).isEqualTo(NOW.plus(LogRules.FUTURE_TOLERANCE));
        assertThat(from.getValue()).isEqualTo(to.getValue().minus(LogRules.DEFAULT_RANGE));
    }

    // ---------- occurrences ----------

    private Reminder reminderFound() {
        Reminder reminder = saved(REMINDER_ID);
        when(repository.findByIdAndPatientId(REMINDER_ID, PATIENT)).thenReturn(Optional.of(reminder));
        return reminder;
    }

    private void eventsSaveAs(long id) {
        when(eventRepository.saveAndFlush(any(ReminderEvent.class))).thenAnswer(call -> {
            ReminderEvent event = call.getArgument(0);
            ReflectionTestUtils.setField(event, "id", id);
            return event;
        });
    }

    @Test
    void aNewOccurrenceIsCreated() {
        Reminder reminder = reminderFound();
        Instant at = Instant.parse("2026-11-23T05:00:00Z");
        when(eventRepository.findByReminderIdAndScheduledFor(REMINDER_ID, at)).thenReturn(Optional.empty());
        eventsSaveAs(900);

        CreateResult<ReminderEventResponse> result = service.reportEvent(PATIENT, PATIENT, REMINDER_ID,
                new ReminderEventRequest(at, ReminderEventStatus.TAKEN));

        assertThat(result.created()).isTrue();
        assertThat(result.log().status()).isEqualTo(ReminderEventStatus.TAKEN);
        assertThat(result.log().acknowledgedAt()).isEqualTo(NOW);
        assertThat(reminder.getLastTriggeredAt()).isEqualTo(at);
        assertThat(reminder.getMissedCount()).isZero();
        verify(repository).saveAndFlush(reminder);
    }

    @Test
    void reportingTheSameOccurrenceAgainChangesIt() {
        Reminder reminder = reminderFound();
        Instant at = Instant.parse("2026-11-23T05:00:00Z");
        ReminderEvent missed = new ReminderEvent(REMINDER_ID, PATIENT, at);
        missed.answer(ReminderEventStatus.MISSED, at);
        when(eventRepository.findByReminderIdAndScheduledFor(REMINDER_ID, at)).thenReturn(Optional.of(missed));
        eventsSaveAs(900);

        CreateResult<ReminderEventResponse> result = service.reportEvent(PATIENT, PATIENT, REMINDER_ID,
                new ReminderEventRequest(at, ReminderEventStatus.TAKEN));

        assertThat(result.created()).isFalse();
        assertThat(result.log().status()).isEqualTo(ReminderEventStatus.TAKEN);
        assertThat(reminder.getMissedCount()).isZero(); // was already MISSED before, not counted again
    }

    @Test
    void aMissedOccurrenceIsCountedOnce() {
        Reminder reminder = reminderFound();
        Instant at = Instant.parse("2026-11-22T05:00:00Z");
        ReminderEvent event = new ReminderEvent(REMINDER_ID, PATIENT, at);
        when(eventRepository.findByReminderIdAndScheduledFor(REMINDER_ID, at))
                .thenReturn(Optional.empty(), Optional.of(event));
        eventsSaveAs(901);

        service.reportEvent(PATIENT, PATIENT, REMINDER_ID, new ReminderEventRequest(at, ReminderEventStatus.MISSED));
        assertThat(reminder.getMissedCount()).isEqualTo(1);

        event.answer(ReminderEventStatus.MISSED, at);
        service.reportEvent(PATIENT, PATIENT, REMINDER_ID, new ReminderEventRequest(at, ReminderEventStatus.MISSED));
        assertThat(reminder.getMissedCount()).isEqualTo(1);
    }

    @Test
    void onlyThePatientsOwnAnswersAreAccepted() {
        reminderFound();

        assertThatThrownBy(() -> service.reportEvent(PATIENT, PATIENT, REMINDER_ID,
                new ReminderEventRequest(NOW, ReminderEventStatus.SENT)))
                .isInstanceOf(InvalidFieldException.class)
                .extracting("field").isEqualTo("status");
    }

    @Test
    void anOccurrenceFarInTheFutureIsRefused() {
        reminderFound();

        assertThatThrownBy(() -> service.reportEvent(PATIENT, PATIENT, REMINDER_ID,
                new ReminderEventRequest(NOW.plus(ReminderService.EARLY_ANSWER_LIMIT).plusSeconds(1),
                        ReminderEventStatus.TAKEN)))
                .isInstanceOf(InvalidFieldException.class)
                .extracting("field").isEqualTo("scheduledFor");
        verify(eventRepository, never()).saveAndFlush(any());
    }

    @Test
    void careTeamCannotReportOccurrences() {
        assertThatThrownBy(() -> service.reportEvent(CLINICIAN, PATIENT, REMINDER_ID,
                new ReminderEventRequest(NOW, ReminderEventStatus.TAKEN)))
                .isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(eventRepository);
    }
}

package com.diamate.backend.service;

import java.time.Clock;
import java.time.DateTimeException;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.ReminderEventRequest;
import com.diamate.backend.api.dto.request.ReminderRequest;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.api.dto.response.ReminderEventResponse;
import com.diamate.backend.api.dto.response.ReminderResponse;
import com.diamate.backend.entity.Reminder;
import com.diamate.backend.entity.ReminderEvent;
import com.diamate.backend.entity.ReminderEventStatus;
import com.diamate.backend.entity.ReminderType;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.ReminderEventRepository;
import com.diamate.backend.repository.ReminderRepository;

/**
 * Reminders of one patient (take a medicine, check glucose ...) and what the patient did with each occurrence.
 *
 * The phone schedules the notifications itself; the backend keeps the reminder definitions (so they survive a new
 * phone and the care team sees the medication plan) and the Taken / Skipped / Missed answers (medication adherence,
 * view v_reminder_adherence_30d). Same access rule as the logs: only the patient writes; the care team reads with the
 * "medications" permission, audited (HealthDataAccess).
 */
@Service
public class ReminderService {

    static final String NOT_FOUND = "Reminder not found";

    /** A handful per patient is normal; the limit only stops a runaway client. */
    static final int MAX_REMINDERS_PER_PATIENT = 50;

    /** A dose may be taken a little before its time; an occurrence further ahead than this is a client error. */
    static final Duration EARLY_ANSWER_LIMIT = Duration.ofDays(1);

    private static final EnumSet<ReminderEventStatus> PATIENT_ANSWERS = EnumSet.of(ReminderEventStatus.TAKEN,
            ReminderEventStatus.SKIPPED, ReminderEventStatus.MISSED);

    private final ReminderRepository repository;
    private final ReminderEventRepository eventRepository;
    private final HealthDataAccess access;
    private final Clock clock;

    public ReminderService(ReminderRepository repository, ReminderEventRepository eventRepository,
            HealthDataAccess access, Clock clock) {
        this.repository = repository;
        this.eventRepository = eventRepository;
        this.access = access;
        this.clock = clock;
    }

    // ---------- reminders ----------

    // Not @Transactional: the access check may write an audit row in its own transaction (see HealthDataAccess).
    public List<ReminderResponse> list(long viewerId, long patientId) {
        access.checkCanRead(viewerId, patientId, PatientDataType.REMINDERS);
        return repository.findByPatientIdOrderByScheduledTimeAscIdAsc(patientId).stream()
                .map(ReminderResponse::from)
                .toList();
    }

    // Not @Transactional, like list().
    public ReminderResponse get(long viewerId, long patientId, long reminderId) {
        access.checkCanRead(viewerId, patientId, PatientDataType.REMINDERS);
        return ReminderResponse.from(find(patientId, reminderId));
    }

    @Transactional
    public ReminderResponse create(long viewerId, long patientId, ReminderRequest request) {
        access.checkCanWrite(viewerId, patientId);
        if (repository.countByPatientId(patientId) >= MAX_REMINDERS_PER_PATIENT) {
            throw new ResourceConflictException("A patient can have at most " + MAX_REMINDERS_PER_PATIENT
                    + " reminders; delete one first");
        }
        Reminder reminder = new Reminder(patientId);
        apply(reminder, request);
        return ReminderResponse.from(repository.saveAndFlush(reminder));
    }

    @Transactional
    public ReminderResponse update(long viewerId, long patientId, long reminderId, ReminderRequest request) {
        access.checkCanWrite(viewerId, patientId);
        Reminder reminder = find(patientId, reminderId);
        apply(reminder, request);
        return ReminderResponse.from(repository.saveAndFlush(reminder));
    }

    /** Removes the reminder and its occurrences (ON DELETE CASCADE). To pause one, send active=false instead. */
    @Transactional
    public void delete(long viewerId, long patientId, long reminderId) {
        access.checkCanWrite(viewerId, patientId);
        repository.delete(find(patientId, reminderId));
    }

    // ---------- occurrences ----------

    /**
     * Records the patient's answer for one occurrence. created = false when that occurrence was already reported:
     * its status is changed (e.g. MISSED, then TAKEN when the patient took it late). missedCount counts an occurrence
     * once, the first time it becomes MISSED.
     */
    @Transactional
    public CreateResult<ReminderEventResponse> reportEvent(long viewerId, long patientId, long reminderId,
            ReminderEventRequest request) {
        access.checkCanWrite(viewerId, patientId);
        Reminder reminder = find(patientId, reminderId);
        if (!PATIENT_ANSWERS.contains(request.status())) {
            throw new InvalidFieldException("status", "Status must be TAKEN, SKIPPED or MISSED");
        }
        Instant scheduledFor = request.scheduledFor();
        if (scheduledFor.isBefore(LogRules.EARLIEST)) {
            throw new InvalidFieldException("scheduledFor", "Time must not be before the year 1900");
        }
        Instant now = clock.instant();
        if (scheduledFor.isAfter(now.plus(EARLY_ANSWER_LIMIT))) {
            throw new InvalidFieldException("scheduledFor", "Must not be more than a day in the future");
        }

        Optional<ReminderEvent> existing = eventRepository.findByReminderIdAndScheduledFor(reminderId, scheduledFor);
        ReminderEvent event = existing.orElseGet(() -> new ReminderEvent(reminderId, patientId, scheduledFor));
        boolean wasMissed = event.getStatus() == ReminderEventStatus.MISSED;
        event.answer(request.status(), now);
        reminder.occurrenceReported(scheduledFor, request.status() == ReminderEventStatus.MISSED && !wasMissed);

        ReminderEventResponse response = ReminderEventResponse.from(eventRepository.saveAndFlush(event));
        repository.saveAndFlush(reminder);
        return existing.isPresent() ? CreateResult.existing(response) : CreateResult.created(response);
    }

    /** Occurrences of all the patient's reminders, newest first. Without from/to: the last 14 days (like the logs). */
    public PageResponse<ReminderEventResponse> events(long viewerId, long patientId, Instant from, Instant to,
            int page, int size) {
        access.checkCanRead(viewerId, patientId, PatientDataType.REMINDERS);
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        return PageResponse.from(eventRepository.findInRange(patientId, window.from(), window.to(),
                window.pageable()), ReminderEventResponse::from);
    }

    // ---------- helpers ----------

    private Reminder find(long patientId, long reminderId) {
        return repository.findByIdAndPatientId(reminderId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    private static void apply(Reminder reminder, ReminderRequest request) {
        ReminderType type = request.reminderType() == null ? ReminderType.MEDICATION : request.reminderType();
        String medicationName = LogRules.text(request.medicationName());
        if (type == ReminderType.MEDICATION && medicationName == null) {
            throw new InvalidFieldException("medicationName", "Medication name is required for a medication reminder");
        }
        reminder.update(type, medicationName, LogRules.text(request.dosage()), LogRules.text(request.message()),
                request.scheduledTime().withSecond(0).withNano(0), daysColumn(request.daysOfWeek()),
                zone(request.timezone()), request.active() == null || request.active());
    }

    /** [FRIDAY, MONDAY, MONDAY] -> "MON,FRI": week order, each day once, the column's three-letter names. */
    static String daysColumn(List<DayOfWeek> days) {
        EnumSet<DayOfWeek> set = EnumSet.copyOf(days);
        return set.stream().map(day -> day.name().substring(0, 3)).collect(Collectors.joining(","));
    }

    /** The phone's time zone: an IANA name or an offset; missing = UTC. */
    static String zone(String timezone) {
        String text = LogRules.text(timezone);
        if (text == null) {
            return "UTC";
        }
        try {
            return ZoneId.of(text).getId();
        } catch (DateTimeException e) {
            throw new InvalidFieldException("timezone", "Must be a time zone such as Europe/Istanbul or +03:00");
        }
    }
}

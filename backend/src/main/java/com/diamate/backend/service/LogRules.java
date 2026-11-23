package com.diamate.backend.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.repository.LogRepository;

/** Rules shared by the four log services (glucose, insulin, meal, activity). */
final class LogRules {

    /** List without from/to: the last 14 days. */
    static final Duration DEFAULT_RANGE = Duration.ofDays(14);

    /** CGM data is ~288 readings a day, so lists are always paged and a page is limited. */
    static final int MAX_PAGE_SIZE = 200;

    /** A phone clock can be a little ahead of the server; times up to 5 minutes in the future are accepted. */
    static final Duration FUTURE_TOLERANCE = Duration.ofMinutes(5);

    /**
     * Times are checked against [1900, 10000) before they reach the database: an older log time can only be a typing
     * error, and the database cannot store years like -1000000000 at all (that was a 500, Week 2 Day 6). A log's
     * time is limited further by FUTURE_TOLERANCE; the upper end only matters for a list's "to".
     */
    static final Instant EARLIEST = Instant.parse("1900-01-01T00:00:00Z");
    static final Instant AFTER_LATEST = Instant.parse("+10000-01-01T00:00:00Z");

    private LogRules() {
    }

    /** Time window [from, to) and page of a list request. */
    record Window(Instant from, Instant to, Pageable pageable) {
    }

    static Window window(Instant from, Instant to, int page, int size, Clock clock) {
        Pageable pageable = page(page, size);
        requireListTime(from, "from");
        requireListTime(to, "to");
        Instant end = to != null ? to : clock.instant().plus(FUTURE_TOLERANCE);
        Instant start = from != null ? from : end.minus(DEFAULT_RANGE);
        if (!start.isBefore(end)) {
            throw new InvalidFieldException("from", "from must be before to");
        }
        return new Window(start, end, pageable);
    }

    /** page and size of a list request (also used by lists without a time window, e.g. alerts). */
    static Pageable page(int page, int size) {
        if (page < 0) {
            throw new InvalidFieldException("page", "Page must be 0 or more");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw new InvalidFieldException("size", "Size must be between 1 and " + MAX_PAGE_SIZE);
        }
        // The database offset (page * size) must fit in an int, otherwise the query cannot even be built (was a 500).
        if ((long) page * size > Integer.MAX_VALUE) {
            throw new InvalidFieldException("page", "Page is too large for this page size");
        }
        return PageRequest.of(page, size);
    }

    private static void requireListTime(Instant time, String field) {
        if (time != null && (time.isBefore(EARLIEST) || !time.isBefore(AFTER_LATEST))) {
            throw new InvalidFieldException(field, "Must be between the years 1900 and 9999");
        }
    }

    /** A log's time: not before 1900, and not in the future (up to FUTURE_TOLERANCE ahead is accepted). */
    static void requireLogTime(Instant time, String field, Clock clock) {
        if (time.isBefore(EARLIEST)) {
            throw new InvalidFieldException(field, "Time must not be before the year 1900");
        }
        if (time.isAfter(clock.instant().plus(FUTURE_TOLERANCE))) {
            throw new InvalidFieldException(field, "Time must not be in the future");
        }
    }

    /** Trims free text; an empty text is stored as null. */
    static String text(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    /** The app's EntrySource (MANUAL / AI_ASSISTANT) as the table's own source enum, which has the same names. */
    static <E extends Enum<E>> E source(EntrySource source, Class<E> type) {
        return Enum.valueOf(type, (source == null ? EntrySource.MANUAL : source).name());
    }

    /**
     * The patient's log with this clientUuid if the app already sent it (a retry), so it is not saved twice. Takes the
     * clientUuid's lock first (LogRepository.lockKey): a request with the same clientUuid that is still running is
     * waited for, and its log is then found here. Must run inside the create transaction, which holds the lock.
     */
    static <T> Optional<T> existing(LogRepository<T> repository, long patientId, UUID clientUuid) {
        if (clientUuid == null) {
            return Optional.empty();
        }
        repository.lockKey(patientId + ":" + clientUuid);
        return repository.findByPatientIdAndClientUuid(patientId, clientUuid);
    }

    /**
     * Inserts at once (flush) so a unique-index clash becomes a 409 here instead of a 500 at commit. The only
     * unique index a new log can clash with is (patient_id, client_uuid), and after existing() only a deleted log can
     * still hold the clientUuid: deleted logs are hidden from the lookup, but the index still contains them. Any other
     * database error is not a conflict and is thrown on (500, logged).
     */
    static <T> T saveNew(JpaRepository<T, Long> repository, T log) {
        try {
            return repository.saveAndFlush(log);
        } catch (DataIntegrityViolationException e) {
            if (DatabaseErrors.isUniqueViolation(e)) {
                throw new ResourceConflictException("This clientUuid belongs to a deleted log; send the entry with a new clientUuid");
            }
            throw e;
        }
    }
}

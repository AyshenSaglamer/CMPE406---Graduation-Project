package com.diamate.backend.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;

/** Rules shared by the four log services (glucose, insulin, meal, activity). */
final class LogRules {

    /** List without from/to: the last 14 days. */
    static final Duration DEFAULT_RANGE = Duration.ofDays(14);

    /** CGM data is ~288 readings a day, so lists are always paged and a page is limited. */
    static final int MAX_PAGE_SIZE = 200;

    /** A phone clock can be a little ahead of the server; times up to 5 minutes in the future are accepted. */
    static final Duration FUTURE_TOLERANCE = Duration.ofMinutes(5);

    private LogRules() {
    }

    /** Time window [from, to) and page of a list request. */
    record Window(Instant from, Instant to, Pageable pageable) {
    }

    static Window window(Instant from, Instant to, int page, int size, Clock clock) {
        if (page < 0) {
            throw new InvalidFieldException("page", "Page must be 0 or more");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw new InvalidFieldException("size", "Size must be between 1 and " + MAX_PAGE_SIZE);
        }
        Instant end = to != null ? to : clock.instant().plus(FUTURE_TOLERANCE);
        Instant start = from != null ? from : end.minus(DEFAULT_RANGE);
        if (!start.isBefore(end)) {
            throw new InvalidFieldException("from", "from must be before to");
        }
        return new Window(start, end, PageRequest.of(page, size));
    }

    static void requireNotInFuture(Instant time, String field, Clock clock) {
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
     * Inserts at once (flush) so a unique-index clash becomes a 409 here instead of a 500 at commit. The only
     * expected clash is a clientUuid that belongs to a deleted log (deleted logs are hidden from the lookup
     * done before the insert, but the unique index still contains them) or a parallel duplicate request.
     */
    static <T> T saveNew(JpaRepository<T, Long> repository, T log) {
        try {
            return repository.saveAndFlush(log);
        } catch (DataIntegrityViolationException e) {
            throw new ResourceConflictException("A log with this clientUuid already exists (it may have been deleted)");
        }
    }
}

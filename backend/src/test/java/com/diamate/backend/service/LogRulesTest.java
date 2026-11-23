package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;

import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.InsulinSource;
import com.diamate.backend.exception.InvalidFieldException;

class LogRulesTest {

    private static final Instant NOW = Instant.parse("2026-10-05T10:00:00Z");
    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);

    @Test
    void withoutFromAndToTheWindowIsTheLast14Days() {
        LogRules.Window window = LogRules.window(null, null, 0, 50, clock);

        assertThat(window.to()).isEqualTo(NOW.plus(LogRules.FUTURE_TOLERANCE));
        assertThat(window.from()).isEqualTo(window.to().minus(LogRules.DEFAULT_RANGE));
        assertThat(window.pageable().getPageNumber()).isZero();
        assertThat(window.pageable().getPageSize()).isEqualTo(50);
    }

    @Test
    void onlyToGivenMeans14DaysBeforeIt() {
        Instant to = Instant.parse("2026-09-01T00:00:00Z");

        LogRules.Window window = LogRules.window(null, to, 2, 10, clock);

        assertThat(window.from()).isEqualTo(Instant.parse("2026-08-18T00:00:00Z"));
        assertThat(window.to()).isEqualTo(to);
    }

    @Test
    void fromMustBeBeforeTo() {
        Instant time = Instant.parse("2026-09-01T00:00:00Z");

        assertThatThrownBy(() -> LogRules.window(time, time, 0, 50, clock))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("from must be before to");
    }

    @Test
    void pageSizeIsLimited() {
        assertThatThrownBy(() -> LogRules.window(null, null, 0, 0, clock)).isInstanceOf(InvalidFieldException.class);
        assertThatThrownBy(() -> LogRules.window(null, null, 0, 201, clock))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Size must be between 1 and 200");
        assertThatThrownBy(() -> LogRules.window(null, null, -1, 50, clock)).isInstanceOf(InvalidFieldException.class);
        assertThat(LogRules.window(null, null, 0, 200, clock).pageable().getPageSize()).isEqualTo(200);
    }

    @Test
    void aPageWhoseOffsetDoesNotFitInAnIntIsAFieldError() {
        // page 2147483647 x 200 rows: the database offset would overflow; this used to end in a 500.
        assertThatThrownBy(() -> LogRules.page(Integer.MAX_VALUE, 200))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Page is too large for this page size")
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("page"));
        assertThat(LogRules.page(10_000_000, 200).getOffset()).isEqualTo(2_000_000_000L); // still fits: allowed
    }

    @Test
    void timesUpTo5MinutesAheadAreAcceptedLaterOnesAreNot() {
        LogRules.requireLogTime(NOW.plusSeconds(300), "measurementTime", clock); // phone clock slightly ahead: OK

        assertThatThrownBy(() -> LogRules.requireLogTime(NOW.plusSeconds(301), "measurementTime", clock))
                .isInstanceOf(InvalidFieldException.class)
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("measurementTime"));
    }

    @Test
    void aLogTimeBefore1900IsAFieldErrorNotADatabaseError() {
        // Week 2 Day 6: year -1000000000 is a valid Instant, but PostgreSQL cannot store it ("timestamp out of range", 500).
        LogRules.requireLogTime(Instant.parse("1900-01-01T00:00:00Z"), "eatenAt", clock);

        for (String time : new String[] { "1899-12-31T23:59:59Z", "0000-01-01T00:00:00Z", "-1000000000-01-01T00:00:00Z" }) {
            assertThatThrownBy(() -> LogRules.requireLogTime(Instant.parse(time), "eatenAt", clock))
                    .isInstanceOf(InvalidFieldException.class)
                    .hasMessage("Time must not be before the year 1900")
                    .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("eatenAt"));
        }
    }

    @Test
    void listFromAndToMustBeBetween1900And9999() {
        assertThat(LogRules.window(Instant.parse("1900-01-01T00:00:00Z"), Instant.parse("9999-12-31T23:59:59Z"), 0, 50,
                clock).to()).isEqualTo(Instant.parse("9999-12-31T23:59:59Z"));

        assertThatThrownBy(() -> LogRules.window(Instant.parse("-999999999-01-01T00:00:00Z"), null, 0, 50, clock))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Must be between the years 1900 and 9999")
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("from"));
        assertThatThrownBy(() -> LogRules.window(null, Instant.parse("1899-12-31T00:00:00Z"), 0, 50, clock))
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("to"));
        assertThatThrownBy(() -> LogRules.window(null, Instant.parse("+10000-01-01T00:00:00Z"), 0, 50, clock))
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("to"));
    }

    @Test
    void blankTextIsStoredAsNull() {
        assertThat(LogRules.text("  after lunch ")).isEqualTo("after lunch");
        assertThat(LogRules.text("   ")).isNull();
        assertThat(LogRules.text(null)).isNull();
    }

    @Test
    void entrySourceMapsToTheTableSourceWithManualAsDefault() {
        assertThat(LogRules.source(null, GlucoseSource.class)).isEqualTo(GlucoseSource.MANUAL);
        assertThat(LogRules.source(EntrySource.AI_ASSISTANT, GlucoseSource.class)).isEqualTo(GlucoseSource.AI_ASSISTANT);
        assertThat(LogRules.source(EntrySource.AI_ASSISTANT, InsulinSource.class)).isEqualTo(InsulinSource.AI_ASSISTANT);
    }
}

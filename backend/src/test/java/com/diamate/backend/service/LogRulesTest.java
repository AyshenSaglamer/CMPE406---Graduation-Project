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
    void timesUpTo5MinutesAheadAreAcceptedLaterOnesAreNot() {
        LogRules.requireNotInFuture(NOW.plusSeconds(300), "measurementTime", clock); // phone clock slightly ahead: OK

        assertThatThrownBy(() -> LogRules.requireNotInFuture(NOW.plusSeconds(301), "measurementTime", clock))
                .isInstanceOf(InvalidFieldException.class)
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("measurementTime"));
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

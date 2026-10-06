package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.entity.Alert;
import com.diamate.backend.entity.AlertSeverity;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.entity.AlertType;
import com.diamate.backend.entity.GlucoseLog;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.repository.AlertRepository;

/** The thresholds themselves are in the database function (checked with Postman against the real database). */
@ExtendWith(MockitoExtension.class)
class GlucoseAlertServiceTest {

    private static final long PATIENT = 5;

    @Mock
    private AlertRepository alertRepository;

    private GlucoseAlertService service;

    @BeforeEach
    void setUp() {
        service = new GlucoseAlertService(alertRepository);
    }

    @Test
    void urgentLowCreatesACriticalOpenAlertLinkedToTheReading() {
        when(alertRepository.classifyGlucose(PATIENT, 48)).thenReturn(Optional.of("URGENT_LOW"));
        when(alertRepository.save(any(Alert.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Alert alert = service.checkReading(reading(100L, 48)).orElseThrow();

        assertThat(alert.getPatientId()).isEqualTo(PATIENT);
        assertThat(alert.getAlertType()).isEqualTo(AlertType.URGENT_LOW);
        assertThat(alert.getSeverity()).isEqualTo(AlertSeverity.CRITICAL);
        assertThat(alert.getStatus()).isEqualTo(AlertStatus.OPEN);
        assertThat(alert.getGlucoseLogId()).isEqualTo(100L);
        assertThat(alert.getValueMgdl()).isEqualByComparingTo(BigDecimal.valueOf(48));
        assertThat(alert.getMessage()).isEqualTo("Urgent low glucose: 48 mg/dL");
    }

    @Test
    void highIsAWarning() {
        when(alertRepository.classifyGlucose(PATIENT, 210)).thenReturn(Optional.of("HIGH"));
        when(alertRepository.save(any(Alert.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Alert alert = service.checkReading(reading(101L, 210)).orElseThrow();

        assertThat(alert.getSeverity()).isEqualTo(AlertSeverity.WARNING);
        assertThat(alert.getMessage()).isEqualTo("High glucose: 210 mg/dL");
    }

    @Test
    void readingInRangeCreatesNoAlert() {
        when(alertRepository.classifyGlucose(PATIENT, 110)).thenReturn(Optional.empty());

        assertThat(service.checkReading(reading(102L, 110))).isEmpty();
        verify(alertRepository, never()).save(any());
    }

    @Test
    void severityOfEveryGlucoseType() {
        assertThat(GlucoseAlertService.severityOf(AlertType.URGENT_LOW)).isEqualTo(AlertSeverity.CRITICAL);
        assertThat(GlucoseAlertService.severityOf(AlertType.LOW)).isEqualTo(AlertSeverity.WARNING);
        assertThat(GlucoseAlertService.severityOf(AlertType.HIGH)).isEqualTo(AlertSeverity.WARNING);
        assertThat(GlucoseAlertService.severityOf(AlertType.URGENT_HIGH)).isEqualTo(AlertSeverity.CRITICAL);
    }

    private static GlucoseLog reading(long id, int value) {
        GlucoseLog log = new GlucoseLog(PATIENT, null, GlucoseSource.MANUAL, PATIENT);
        log.update(value, Instant.parse("2026-10-05T08:30:00Z"), null, null);
        ReflectionTestUtils.setField(log, "id", id);
        return log;
    }
}

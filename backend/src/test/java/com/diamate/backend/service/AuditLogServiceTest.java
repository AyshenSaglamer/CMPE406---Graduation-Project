package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

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

import com.diamate.backend.api.dto.response.AccessLogEntryResponse;
import com.diamate.backend.api.dto.response.AuditLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.AuditLogRepository;
import com.diamate.backend.repository.AuditLogRepository.AuditRow;
import com.diamate.backend.repository.AuditLogRepository.Filter;
import com.diamate.backend.repository.AuditLogRepository.PatientAccessRow;

import tools.jackson.databind.json.JsonMapper;

@ExtendWith(MockitoExtension.class)
class AuditLogServiceTest {

    private static final long PATIENT = 5;
    private static final long CLINICIAN = 2;
    private static final long ADMIN = 1;
    private static final Instant NOW = Instant.parse("2026-11-17T12:00:00Z");

    @Mock
    private AuditLogRepository repository;

    @Mock
    private AuditService auditService;

    private AuditLogService service;

    @BeforeEach
    void setUp() {
        service = new AuditLogService(repository, auditService, JsonMapper.builder().build(),
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    // ---------- the patient's access log ----------

    @Test
    void patientSeesWhoReadTheirDataWithNamesButNoIpAddress() {
        Instant at = NOW.minus(Duration.ofHours(2));
        when(repository.countForPatient(eq(PATIENT), any(), any())).thenReturn(2L);
        when(repository.findForPatient(eq(PATIENT), any(), any(), eq(0L), eq(50))).thenReturn(List.of(
                new PatientAccessRow(11, at, CLINICIAN, "Mehmet", "Demir", "CLINICIAN", "VIEW_PATIENT_DATA",
                        "MEAL_LOGS", null, false, null),
                new PatientAccessRow(10, at, CLINICIAN, "Mehmet", "Demir", "CLINICIAN", "ALERT_STATUS_CHANGED",
                        "ALERT", "77", true, "{\"from\":\"OPEN\",\"to\":\"ACKNOWLEDGED\"}")));

        PageResponse<AccessLogEntryResponse> log = service.patientAccessLog(PATIENT, PATIENT, null, null, 0, 50);

        assertThat(log.totalElements()).isEqualTo(2);
        assertThat(log.totalPages()).isEqualTo(1);
        AccessLogEntryResponse refused = log.items().get(0);
        assertThat(refused.actorFirstName()).isEqualTo("Mehmet");
        assertThat(refused.dataType()).isEqualTo("MEAL_LOGS");
        assertThat(refused.success()).isFalse();
        assertThat(log.items().get(1).details()).containsEntry("to", "ACKNOWLEDGED");
        verifyNoInteractions(auditService); // the patient reading their own log is not audited
    }

    @Test
    void defaultWindowIsTheLast14Days() {
        service.patientAccessLog(PATIENT, PATIENT, null, null, 0, 50);

        ArgumentCaptor<Instant> from = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> to = ArgumentCaptor.forClass(Instant.class);
        verify(repository).countForPatient(eq(PATIENT), from.capture(), to.capture());
        assertThat(Duration.between(from.getValue(), to.getValue())).isEqualTo(Duration.ofDays(14));
        assertThat(to.getValue()).isAfter(NOW);
    }

    @Test
    void nobodyElseSeesAPatientsAccessLog() {
        for (long viewer : new long[] { CLINICIAN, ADMIN, 6 }) {
            assertThatThrownBy(() -> service.patientAccessLog(viewer, PATIENT, null, null, 0, 50))
                    .isInstanceOf(ResourceNotFoundException.class)
                    .hasMessage("Patient not found");
        }
        verifyNoInteractions(repository);
    }

    @Test
    void accessLogUsesTheListRules() {
        assertThatThrownBy(() -> service.patientAccessLog(PATIENT, PATIENT, null, null, 0, 201))
                .isInstanceOfSatisfying(InvalidFieldException.class, e -> assertThat(e.getField()).isEqualTo("size"));
        assertThatThrownBy(() -> service.patientAccessLog(PATIENT, PATIENT, NOW, NOW.minusSeconds(1), 0, 50))
                .isInstanceOfSatisfying(InvalidFieldException.class, e -> assertThat(e.getField()).isEqualTo("from"));
        verifyNoInteractions(repository);
    }

    @Test
    void secondPageStartsAfterTheFirst() {
        service.patientAccessLog(PATIENT, PATIENT, null, null, 2, 20);

        verify(repository).findForPatient(eq(PATIENT), any(), any(), eq(40L), eq(20));
    }

    // ---------- the ADMIN's search ----------

    @Test
    void adminSearchesWithFiltersAndTheSearchIsAudited() {
        Instant from = NOW.minus(Duration.ofDays(1));
        when(repository.countMatching(any())).thenReturn(1L);
        when(repository.findMatching(any(), anyLong(), anyInt())).thenReturn(List.of(new AuditRow(7, NOW, null, null,
                "LOGIN_FAILED", null, null, false, "{\"reason\":\"UNKNOWN_EMAIL\"}", "10.0.0.7", "curl/8")));

        PageResponse<AuditLogResponse> page = service.search(ADMIN, null, null, " LOGIN_FAILED ", false, from, NOW, 0,
                50);

        assertThat(page.items()).singleElement().satisfies(row -> {
            assertThat(row.ipAddress()).isEqualTo("10.0.0.7");
            assertThat(row.details()).containsEntry("reason", "UNKNOWN_EMAIL");
        });
        ArgumentCaptor<Filter> filter = ArgumentCaptor.forClass(Filter.class);
        verify(repository).countMatching(filter.capture());
        assertThat(filter.getValue()).isEqualTo(new Filter(from, NOW, null, null, "LOGIN_FAILED", false));
        verify(auditService).auditLogViewed(ADMIN, Map.of("from", from.toString(), "to", NOW.toString(),
                "action", "LOGIN_FAILED", "success", "false"));
    }

    @Test
    void anActionThatIsNotAnActionNameIs400BeforeAnyQuery() {
        for (String action : List.of("login_failed", "LOGIN' OR '1'='1", "X".repeat(61), "LOGIN-FAILED")) {
            assertThatThrownBy(() -> service.search(ADMIN, null, null, action, null, null, null, 0, 50))
                    .isInstanceOfSatisfying(InvalidFieldException.class,
                            e -> assertThat(e.getField()).isEqualTo("action"));
        }
        verifyNoInteractions(repository, auditService);
    }

    @Test
    void blankActionMeansAnyAction() {
        service.search(ADMIN, 5L, null, "  ", null, null, null, 0, 50);

        ArgumentCaptor<Filter> filter = ArgumentCaptor.forClass(Filter.class);
        verify(repository).countMatching(filter.capture());
        assertThat(filter.getValue().action()).isNull();
        assertThat(filter.getValue().userId()).isEqualTo(5L);
    }
}

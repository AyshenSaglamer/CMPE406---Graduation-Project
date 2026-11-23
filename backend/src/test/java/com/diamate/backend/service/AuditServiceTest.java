package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;

import java.time.Instant;
import java.util.Map;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.diamate.backend.repository.AuditLogRepository;
import com.diamate.backend.security.RoleAccessDeniedEvent;
import com.diamate.backend.service.AuditService.LoginFailure;

import tools.jackson.databind.json.JsonMapper;

@ExtendWith(MockitoExtension.class)
class AuditServiceTest {

    @Mock
    private AuditLogRepository repository;

    private AuditService service;

    @BeforeEach
    void setUp() {
        service = new AuditService(repository, JsonMapper.builder().build());
    }

    @AfterEach
    void clearRequest() {
        RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void failedLoginStoresTheReasonAndTheClientButNoEmail() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.7");
        request.addHeader("User-Agent", "DiaMate/1.0 (iOS 19)");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));

        service.loginFailed(5L, LoginFailure.WRONG_PASSWORD);

        AuditLogRepository.Entry entry = written();
        assertThat(entry.userId()).isEqualTo(5L);
        assertThat(entry.action()).isEqualTo("LOGIN_FAILED");
        assertThat(entry.success()).isFalse();
        assertThat(entry.detailsJson()).isEqualTo("{\"reason\":\"WRONG_PASSWORD\"}");
        assertThat(entry.ipAddress()).isEqualTo("10.0.0.7");
        assertThat(entry.userAgent()).isEqualTo("DiaMate/1.0 (iOS 19)");
    }

    @Test
    void lockIsStoredWithItsEndTime() {
        service.accountLocked(5L, Instant.parse("2026-10-06T12:15:00Z"));

        AuditLogRepository.Entry entry = written();
        assertThat(entry.action()).isEqualTo("ACCOUNT_LOCKED");
        assertThat(entry.detailsJson()).isEqualTo("{\"lockedUntil\":\"2026-10-06T12:15:00Z\"}");
    }

    @Test
    void readOfAnotherPatientsDataStoresWhoWhoseWhatAndTheResult() {
        service.patientDataViewed(2L, 5L, PatientDataType.INSULIN_LOGS, false);

        AuditLogRepository.Entry entry = written();
        assertThat(entry.userId()).isEqualTo(2L);
        assertThat(entry.patientId()).isEqualTo(5L);
        assertThat(entry.action()).isEqualTo("VIEW_PATIENT_DATA");
        assertThat(entry.entityType()).isEqualTo("INSULIN_LOGS");
        assertThat(entry.success()).isFalse();
        assertThat(entry.detailsJson()).isNull();
        assertThat(entry.ipAddress()).isNull(); // no HTTP request in this test
    }

    @Test
    void veryLongUserAgentIsCutToTheColumnSize() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("User-Agent", "x".repeat(1000));
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));

        service.loginSucceeded(5L);

        assertThat(written().userAgent()).hasSize(255);
    }

    @Test
    void registrationStoresTheRoleAndWhetherTheAccountIsActive() {
        service.registered(43L, "CLINICIAN", false);

        AuditLogRepository.Entry entry = written();
        assertThat(entry.userId()).isEqualTo(43L);
        assertThat(entry.action()).isEqualTo("REGISTER");
        assertThat(entry.entityType()).isEqualTo("USER");
        assertThat(entry.entityId()).isEqualTo("43");
        assertThat(entry.detailsJson()).isEqualTo("{\"role\":\"CLINICIAN\",\"active\":\"false\"}")
                .doesNotContain("@"); // no email
    }

    @Test
    void healthLogChangeStoresWhichLogButNoValues() {
        service.healthLogChanged(5L, 5L, PatientDataType.GLUCOSE_LOGS, 100L,
                AuditService.HealthLogChange.HEALTH_LOG_DELETED);

        AuditLogRepository.Entry entry = written();
        assertThat(entry.userId()).isEqualTo(5L);
        assertThat(entry.patientId()).isEqualTo(5L);
        assertThat(entry.action()).isEqualTo("HEALTH_LOG_DELETED");
        assertThat(entry.entityType()).isEqualTo("GLUCOSE_LOGS");
        assertThat(entry.entityId()).isEqualTo("100");
        assertThat(entry.detailsJson()).isNull();
    }

    @Test
    void refusedRoleStoresMethodAndPathAsAFailure() {
        service.onAccessDenied(new RoleAccessDeniedEvent(5L, "GET", "/api/v1/admin/users"));

        AuditLogRepository.Entry entry = written();
        assertThat(entry.userId()).isEqualTo(5L);
        assertThat(entry.action()).isEqualTo("ACCESS_DENIED");
        assertThat(entry.success()).isFalse();
        assertThat(entry.detailsJson()).isEqualTo("{\"method\":\"GET\",\"path\":\"/api/v1/admin/users\"}");
    }

    @Test
    void veryLongRefusedPathIsCut() {
        service.accessDenied(5L, "GET", "/api/v1/admin/" + "a".repeat(5000));

        assertThat(written().detailsJson()).hasSizeLessThan(AuditService.PATH_MAX_LENGTH + 50);
    }

    @Test
    void adminReadingTheTrailIsAuditedWithTheFilters() {
        service.auditLogViewed(1L, Map.of("action", "LOGIN_FAILED"));

        AuditLogRepository.Entry entry = written();
        assertThat(entry.userId()).isEqualTo(1L);
        assertThat(entry.action()).isEqualTo("AUDIT_LOG_VIEWED");
        assertThat(entry.detailsJson()).isEqualTo("{\"action\":\"LOGIN_FAILED\"}");
    }

    private AuditLogRepository.Entry written() {
        ArgumentCaptor<AuditLogRepository.Entry> entry = ArgumentCaptor.forClass(AuditLogRepository.Entry.class);
        verify(repository).insert(entry.capture());
        return entry.getValue();
    }
}

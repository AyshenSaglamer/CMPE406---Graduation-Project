package com.diamate.backend.api.controller;

import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import com.diamate.backend.api.dto.response.AlertResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.AlertSeverity;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.entity.AlertType;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.AlertService;

/**
 * Alert endpoints with the real SecurityConfig, real signed tokens, validation and GlobalExceptionHandler.
 * The service is a mock (its rules are tested in AlertServiceTest).
 */
@WebMvcTest(
        controllers = AlertController.class,
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class AlertWebTest {

    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final long ALERT_ID = 40;
    private static final Instant TRIGGERED = Instant.parse("2026-10-12T08:30:00Z");
    private static final String ALERTS_URL = "/api/v1/patients/{patientId}/alerts";
    private static final String ALERT_URL = ALERTS_URL + "/{alertId}";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private AlertService alertService;

    @MockitoBean
    private UserRepository userRepository;

    @BeforeEach
    void everyAccountIsActive() {
        when(userRepository.findActiveUserRole(anyLong())).thenAnswer(call -> Optional.of(roleOf(call.getArgument(0))));
    }

    @Test
    void withoutTokenIs401() throws Exception {
        mockMvc.perform(get(ALERTS_URL, PATIENT_ID)).andExpect(status().isUnauthorized());
        mockMvc.perform(patch(ALERT_URL, PATIENT_ID, ALERT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"status\":\"ACKNOWLEDGED\"}")).andExpect(status().isUnauthorized());
        verifyNoInteractions(alertService);
    }

    @Test
    void listPassesTheFiltersAndReturnsAPage() throws Exception {
        when(alertService.list(PATIENT_ID, PATIENT_ID, AlertStatus.OPEN, null, null, 0, 20))
                .thenReturn(new PageResponse<>(List.of(alert(AlertStatus.OPEN)), 0, 20, 1, 1));

        as(get(ALERTS_URL, PATIENT_ID).param("status", "OPEN").param("size", "20"), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].id").value(ALERT_ID))
                .andExpect(jsonPath("$.items[0].alertType").value("LOW"))
                .andExpect(jsonPath("$.items[0].severity").value("WARNING"))
                .andExpect(jsonPath("$.items[0].valueMgdl").value(62.0))
                .andExpect(jsonPath("$.items[0].status").value("OPEN"));
    }

    @Test
    void unknownStatusFilterIs400() throws Exception {
        as(get(ALERTS_URL, PATIENT_ID).param("status", "SOMETHING"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(alertService);
    }

    @Test
    void clinicianAcknowledgesAnAlert() throws Exception {
        when(alertService.changeStatus(CLINICIAN_ID, PATIENT_ID, ALERT_ID, AlertStatus.ACKNOWLEDGED))
                .thenReturn(alert(AlertStatus.ACKNOWLEDGED));

        as(patch(ALERT_URL, PATIENT_ID, ALERT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"status\":\"ACKNOWLEDGED\"}"), CLINICIAN_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACKNOWLEDGED"));
    }

    @Test
    void missingStatusIs400WithFieldError() throws Exception {
        as(patch(ALERT_URL, PATIENT_ID, ALERT_ID).contentType(MediaType.APPLICATION_JSON).content("{}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.status").value("Status is required"));
        verifyNoInteractions(alertService);
    }

    @Test
    void serviceErrorsBecome404And409() throws Exception {
        when(alertService.get(CLINICIAN_ID, PATIENT_ID, ALERT_ID))
                .thenThrow(new ResourceNotFoundException("Patient not found"));
        when(alertService.changeStatus(PATIENT_ID, PATIENT_ID, ALERT_ID, AlertStatus.ACKNOWLEDGED))
                .thenThrow(new ResourceConflictException("Alert is already resolved"));

        as(get(ALERT_URL, PATIENT_ID, ALERT_ID), CLINICIAN_ID)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Patient not found"));
        as(patch(ALERT_URL, PATIENT_ID, ALERT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"status\":\"ACKNOWLEDGED\"}"), PATIENT_ID)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.detail").value("Alert is already resolved"));
    }

    @Test
    void listWithoutFiltersSendsNulls() throws Exception {
        when(alertService.list(eq(PATIENT_ID), eq(PATIENT_ID), isNull(), isNull(), isNull(), eq(0), eq(50)))
                .thenReturn(new PageResponse<>(List.of(), 0, 50, 0, 0));

        as(get(ALERTS_URL, PATIENT_ID), PATIENT_ID).andExpect(status().isOk());

        verify(alertService).list(PATIENT_ID, PATIENT_ID, null, null, null, 0, 50);
    }

    // ---------- helpers ----------

    private static AlertResponse alert(AlertStatus status) {
        boolean handled = status != AlertStatus.OPEN;
        return new AlertResponse(ALERT_ID, PATIENT_ID, AlertType.LOW, AlertSeverity.WARNING, 100L,
                new BigDecimal("62.0"), "Low glucose: 62 mg/dL", status, TRIGGERED, handled ? CLINICIAN_ID : null,
                handled ? TRIGGERED.plusSeconds(60) : null, null, null);
    }

    /** Sends the request with a real token signed by the application's JwtEncoder. */
    private ResultActions as(MockHttpServletRequestBuilder request, long userId) throws Exception {
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenFor(userId, roleOf(userId))));
    }

    private String tokenFor(long userId, Role role) {
        User user = new User("First", "Last", LocalDate.of(2000, 1, 15), Gender.OTHER, role, "u" + userId + "@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", userId);
        return new JwtService(jwtEncoder, jwtProperties, Clock.systemUTC()).generateToken(user);
    }

    private static Role roleOf(long id) {
        return id == CLINICIAN_ID ? Role.CLINICIAN : Role.PATIENT;
    }
}

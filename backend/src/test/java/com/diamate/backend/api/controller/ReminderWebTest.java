package com.diamate.backend.api.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
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

import com.diamate.backend.api.dto.request.ReminderEventRequest;
import com.diamate.backend.api.dto.request.ReminderRequest;
import com.diamate.backend.api.dto.response.ReminderEventResponse;
import com.diamate.backend.api.dto.response.ReminderResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.ReminderEventStatus;
import com.diamate.backend.entity.ReminderType;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.CreateResult;
import com.diamate.backend.service.ReminderService;

/**
 * Reminder endpoints with the real SecurityConfig, real signed tokens, JSON reading, validation and
 * GlobalExceptionHandler. The service is a mock (its rules are tested in ReminderServiceTest).
 */
@WebMvcTest(
        controllers = ReminderController.class,
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class ReminderWebTest {

    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final long CAREGIVER_ID = 4;
    private static final long DEPENDENT_ID = 9;
    private static final long REMINDER_ID = 60;
    private static final String REMINDERS_URL = "/api/v1/patients/{patientId}/reminders";
    private static final String REMINDER_URL = REMINDERS_URL + "/{reminderId}";
    private static final String METFORMIN = """
            {"medicationName":"Metformin","dosage":"500 mg","scheduledTime":"08:00",
             "daysOfWeek":["MONDAY","FRIDAY"],"timezone":"Europe/Istanbul"}""";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private ReminderService reminderService;

    @MockitoBean
    private UserRepository userRepository;

    @BeforeEach
    void everyAccountIsActive() {
        when(userRepository.findRoleForOpenSession(anyLong(), any(), any())).thenAnswer(call -> Optional.of(roleOf(call.getArgument(0))));
    }

    @Test
    void withoutTokenIs401() throws Exception {
        mockMvc.perform(get(REMINDERS_URL, PATIENT_ID)).andExpect(status().isUnauthorized());
        verifyNoInteractions(reminderService);
    }

    @Test
    void createReadsTimeAndDaysAndAnswers201WithLocation() throws Exception {
        when(reminderService.create(eq(PATIENT_ID), eq(PATIENT_ID), any())).thenReturn(reminder());

        as(post(REMINDERS_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(METFORMIN), PATIENT_ID)
                .andExpect(status().isCreated())
                .andExpect(header().string(HttpHeaders.LOCATION, "http://localhost/api/v1/patients/5/reminders/60"))
                .andExpect(jsonPath("$.scheduledTime").value("08:00:00"))
                .andExpect(jsonPath("$.daysOfWeek[0]").value("MONDAY"))
                .andExpect(jsonPath("$.reminderType").value("MEDICATION"));

        ArgumentCaptor<ReminderRequest> sent = ArgumentCaptor.forClass(ReminderRequest.class);
        verify(reminderService).create(eq(PATIENT_ID), eq(PATIENT_ID), sent.capture());
        assertThat(sent.getValue().scheduledTime()).isEqualTo(LocalTime.of(8, 0));
        assertThat(sent.getValue().daysOfWeek()).containsExactly(DayOfWeek.MONDAY, DayOfWeek.FRIDAY);
    }

    @Test
    void missingTimeAndDaysAre400WithFieldErrors() throws Exception {
        as(post(REMINDERS_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"medicationName\":\"Metformin\",\"daysOfWeek\":[]}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.scheduledTime").value("Time is required"))
                .andExpect(jsonPath("$.errors.daysOfWeek").value("Choose at least one day"));
        verifyNoInteractions(reminderService);
    }

    @Test
    void anUnknownDayOrABadTimeIs400() throws Exception {
        as(post(REMINDERS_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(
                "{\"medicationName\":\"M\",\"scheduledTime\":\"08:00\",\"daysOfWeek\":[\"FUNDAY\"]}"), PATIENT_ID)
                .andExpect(status().isBadRequest());
        as(post(REMINDERS_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(
                "{\"medicationName\":\"M\",\"scheduledTime\":\"25:00\",\"daysOfWeek\":[\"MONDAY\"]}"), PATIENT_ID)
                .andExpect(status().isBadRequest());
        verifyNoInteractions(reminderService);
    }

    @Test
    void aClinicianCannotWriteButCanRead() throws Exception {
        when(reminderService.list(CLINICIAN_ID, PATIENT_ID)).thenReturn(List.of(reminder()));

        as(put(REMINDER_URL, PATIENT_ID, REMINDER_ID).contentType(MediaType.APPLICATION_JSON).content(METFORMIN),
                CLINICIAN_ID).andExpect(status().isForbidden());
        as(get(REMINDERS_URL, PATIENT_ID), CLINICIAN_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].medicationName").value("Metformin"));
    }

    @Test
    void aCaregiverPassesTheRoleCheckAndTheServiceDecidesWhichPatient() throws Exception {
        // The managing caregiver of a dependent (V12) writes; for any other patient the service answers 404.
        when(reminderService.create(eq(CAREGIVER_ID), eq(DEPENDENT_ID), any())).thenReturn(reminder());
        when(reminderService.create(eq(CAREGIVER_ID), eq(PATIENT_ID), any()))
                .thenThrow(new ResourceNotFoundException("Patient not found"));

        as(post(REMINDERS_URL, DEPENDENT_ID).contentType(MediaType.APPLICATION_JSON).content(METFORMIN), CAREGIVER_ID)
                .andExpect(status().isCreated());
        as(post(REMINDERS_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(METFORMIN), CAREGIVER_ID)
                .andExpect(status().isNotFound());
        as(delete(REMINDER_URL, DEPENDENT_ID, REMINDER_ID), CAREGIVER_ID).andExpect(status().isNoContent());
        verify(reminderService).delete(CAREGIVER_ID, DEPENDENT_ID, REMINDER_ID);
    }

    @Test
    void notFoundIs404AndDeleteIs204() throws Exception {
        when(reminderService.get(PATIENT_ID, PATIENT_ID, REMINDER_ID))
                .thenThrow(new ResourceNotFoundException("Reminder not found"));

        as(get(REMINDER_URL, PATIENT_ID, REMINDER_ID), PATIENT_ID)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Reminder not found"));
        as(delete(REMINDER_URL, PATIENT_ID, REMINDER_ID), PATIENT_ID).andExpect(status().isNoContent());
        verify(reminderService).delete(PATIENT_ID, PATIENT_ID, REMINDER_ID);
    }

    @Test
    void anOccurrenceIs201WhenNewAnd200WhenReportedAgain() throws Exception {
        Instant at = Instant.parse("2026-11-23T05:00:00Z");
        ReminderEventResponse taken = new ReminderEventResponse(900, REMINDER_ID, PATIENT_ID, at,
                ReminderEventStatus.TAKEN, at);
        when(reminderService.reportEvent(eq(PATIENT_ID), eq(PATIENT_ID), eq(REMINDER_ID), any()))
                .thenReturn(CreateResult.created(taken), CreateResult.existing(taken));
        String body = "{\"scheduledFor\":\"2026-11-23T05:00:00Z\",\"status\":\"TAKEN\"}";

        as(post(REMINDER_URL + "/events", PATIENT_ID, REMINDER_ID).contentType(MediaType.APPLICATION_JSON)
                .content(body), PATIENT_ID)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("TAKEN"));
        as(post(REMINDER_URL + "/events", PATIENT_ID, REMINDER_ID).contentType(MediaType.APPLICATION_JSON)
                .content(body), PATIENT_ID)
                .andExpect(status().isOk());

        ArgumentCaptor<ReminderEventRequest> sent = ArgumentCaptor.forClass(ReminderEventRequest.class);
        verify(reminderService, org.mockito.Mockito.times(2))
                .reportEvent(eq(PATIENT_ID), eq(PATIENT_ID), eq(REMINDER_ID), sent.capture());
        assertThat(sent.getValue().scheduledFor()).isEqualTo(at);
    }

    @Test
    void anOccurrenceWithoutStatusIs400() throws Exception {
        as(post(REMINDER_URL + "/events", PATIENT_ID, REMINDER_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"scheduledFor\":\"2026-11-23T05:00:00Z\"}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.status").value("Status is required"));
        verifyNoInteractions(reminderService);
    }

    // ---------- helpers ----------

    private static ReminderResponse reminder() {
        return new ReminderResponse(REMINDER_ID, PATIENT_ID, ReminderType.MEDICATION, "Metformin", "500 mg", null,
                LocalTime.of(8, 0), List.of(DayOfWeek.MONDAY, DayOfWeek.FRIDAY), "Europe/Istanbul", true, 0, null,
                Instant.parse("2026-11-23T09:00:00Z"), Instant.parse("2026-11-23T09:00:00Z"));
    }

    /** Sends the request with a real token signed by the application's JwtEncoder. */
    private ResultActions as(MockHttpServletRequestBuilder request, long userId) throws Exception {
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenFor(userId, roleOf(userId))));
    }

    private String tokenFor(long userId, Role role) {
        User user = new User("First", "Last", LocalDate.of(2000, 1, 15), Gender.OTHER, role, "u" + userId + "@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", userId);
        return new JwtService(jwtEncoder, jwtProperties, Clock.systemUTC()).generateToken(user, java.util.UUID.randomUUID());
    }

    private static Role roleOf(long id) {
        if (id == CLINICIAN_ID) {
            return Role.CLINICIAN;
        }
        return id == CAREGIVER_ID ? Role.CAREGIVER : Role.PATIENT;
    }
}

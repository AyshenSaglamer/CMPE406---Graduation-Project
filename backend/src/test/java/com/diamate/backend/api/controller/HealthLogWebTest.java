package com.diamate.backend.api.controller;

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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

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

import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.InsulinLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.ActivitySource;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.InsulinDeliveryMethod;
import com.diamate.backend.entity.InsulinSource;
import com.diamate.backend.entity.InsulinType;
import com.diamate.backend.entity.MealContext;
import com.diamate.backend.entity.MealSource;
import com.diamate.backend.entity.MealType;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AiServiceException;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.ActivityLogService;
import com.diamate.backend.service.AiService;
import com.diamate.backend.service.CreateResult;
import com.diamate.backend.service.GlucoseLogService;
import com.diamate.backend.service.InsulinLogService;
import com.diamate.backend.service.MealLogService;

/**
 * Health log and AI endpoints with the real SecurityConfig, real signed tokens, validation and
 * GlobalExceptionHandler. The services are mocks (their rules are tested in the service tests).
 */
@WebMvcTest(
        controllers = { GlucoseLogController.class, InsulinLogController.class, MealLogController.class,
                ActivityLogController.class, AiController.class },
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class })
class HealthLogWebTest {

    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final long CAREGIVER_ID = 4;
    private static final long ADMIN_ID = 1;
    private static final Instant MEASURED = Instant.parse("2026-10-05T08:30:00Z");
    private static final String GLUCOSE_URL = "/api/v1/patients/{patientId}/glucose-logs";
    private static final String VALID_GLUCOSE = """
            {"glucoseValue":125,"measurementTime":"2026-10-05T08:30:00Z","mealContext":"FASTING"}""";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private GlucoseLogService glucoseLogService;

    @MockitoBean
    private InsulinLogService insulinLogService;

    @MockitoBean
    private MealLogService mealLogService;

    @MockitoBean
    private ActivityLogService activityLogService;

    @MockitoBean
    private AiService aiService;

    // ---------- authentication and roles ----------

    @Test
    void withoutTokenIs401() throws Exception {
        mockMvc.perform(get(GLUCOSE_URL, PATIENT_ID)).andExpect(status().isUnauthorized());
        mockMvc.perform(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(VALID_GLUCOSE))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(glucoseLogService);
    }

    @Test
    void onlyPatientsCanWriteLogs() throws Exception {
        for (long id : new long[] { CLINICIAN_ID, CAREGIVER_ID, ADMIN_ID }) {
            as(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(VALID_GLUCOSE), id)
                    .andExpect(status().isForbidden())
                    .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
            as(put(GLUCOSE_URL + "/{logId}", PATIENT_ID, 100).contentType(MediaType.APPLICATION_JSON)
                    .content(VALID_GLUCOSE), id).andExpect(status().isForbidden());
            as(delete(GLUCOSE_URL + "/{logId}", PATIENT_ID, 100), id).andExpect(status().isForbidden());
        }
        verifyNoInteractions(glucoseLogService);
    }

    @Test
    void clinicianCanReadWhenTheServiceAllowsIt() throws Exception {
        when(glucoseLogService.list(eq(CLINICIAN_ID), eq(PATIENT_ID), any(), any(), eq(0), eq(50)))
                .thenReturn(new PageResponse<>(List.of(glucose(100L, false)), 0, 50, 1, 1));

        as(get(GLUCOSE_URL, PATIENT_ID), CLINICIAN_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].glucoseValue").value(125))
                .andExpect(jsonPath("$.items[0].measurementTime").value("2026-10-05T08:30:00Z"))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(50));
    }

    @Test
    void noAccessIs404ProblemDetail() throws Exception {
        when(glucoseLogService.list(eq(ADMIN_ID), eq(PATIENT_ID), any(), any(), eq(0), eq(50)))
                .thenThrow(new ResourceNotFoundException("Patient not found"));

        as(get(GLUCOSE_URL, PATIENT_ID), ADMIN_ID)
                .andExpect(status().isNotFound())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Patient not found"));
    }

    // ---------- create ----------

    @Test
    void newLogIs201WithLocationAndTheIdComesFromTheToken() throws Exception {
        when(glucoseLogService.create(eq(PATIENT_ID), eq(PATIENT_ID), any(GlucoseLogRequest.class)))
                .thenReturn(CreateResult.created(glucose(100L, false)));

        as(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(VALID_GLUCOSE), PATIENT_ID)
                .andExpect(status().isCreated())
                .andExpect(header().string(HttpHeaders.LOCATION, "http://localhost/api/v1/patients/5/glucose-logs/100"))
                .andExpect(jsonPath("$.id").value(100))
                .andExpect(jsonPath("$.source").value("MANUAL"));
        verify(glucoseLogService).create(eq(PATIENT_ID), eq(PATIENT_ID), any(GlucoseLogRequest.class));
    }

    @Test
    void resentLogIs200WithTheExistingLog() throws Exception {
        when(glucoseLogService.create(eq(PATIENT_ID), eq(PATIENT_ID), any(GlucoseLogRequest.class)))
                .thenReturn(CreateResult.existing(glucose(100L, true)));

        as(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content("""
                {"glucoseValue":125,"measurementTime":"2026-10-05T08:30:00Z",
                 "clientUuid":"3f1c2a9e-8d7b-4c6a-9e5f-1a2b3c4d5e6f"}"""), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist(HttpHeaders.LOCATION))
                .andExpect(jsonPath("$.id").value(100));
    }

    @Test
    void invalidFieldsAre400WithAnErrorPerField() throws Exception {
        as(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"glucoseValue\":5}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.title").value("Validation failed"))
                .andExpect(jsonPath("$.errors.glucoseValue").value("Glucose value must be at least 10 mg/dL"))
                .andExpect(jsonPath("$.errors.measurementTime").value("Measurement time is required"));
        verifyNoInteractions(glucoseLogService);
    }

    @Test
    void unknownEnumValueIs400() throws Exception {
        as(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content("""
                {"glucoseValue":125,"measurementTime":"2026-10-05T08:30:00Z","mealContext":"LUNCH"}"""), PATIENT_ID)
                .andExpect(status().isBadRequest());
        verifyNoInteractions(glucoseLogService);
    }

    @Test
    void ruleBrokenInTheServiceHasTheSameShapeAsValidationErrors() throws Exception {
        when(glucoseLogService.create(eq(PATIENT_ID), eq(PATIENT_ID), any(GlucoseLogRequest.class)))
                .thenThrow(new InvalidFieldException("measurementTime", "Time must not be in the future"));

        as(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(VALID_GLUCOSE), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.title").value("Validation failed"))
                .andExpect(jsonPath("$.errors.measurementTime").value("Time must not be in the future"));
    }

    // ---------- list parameters ----------

    @Test
    void fromAndToAreReadAsIsoTimesIncludingOffsets() throws Exception {
        when(glucoseLogService.list(anyLong(), anyLong(), any(), any(), eq(2), eq(10)))
                .thenReturn(new PageResponse<>(List.of(), 2, 10, 0, 0));

        // .param() encodes the values; in a hand-written URL "+" must be sent as %2B (a plain "+" means a space).
        as(get(GLUCOSE_URL, PATIENT_ID).param("from", "2026-10-01T00:00:00Z").param("to", "2026-10-05T03:00:00+03:00")
                .param("page", "2").param("size", "10"), PATIENT_ID)
                .andExpect(status().isOk());

        verify(glucoseLogService).list(PATIENT_ID, PATIENT_ID, Instant.parse("2026-10-01T00:00:00Z"),
                Instant.parse("2026-10-05T00:00:00Z"), 2, 10);
    }

    @Test
    void badTimeParameterIs400() throws Exception {
        as(get(GLUCOSE_URL + "?from=yesterday", PATIENT_ID), PATIENT_ID).andExpect(status().isBadRequest());
        verifyNoInteractions(glucoseLogService);
    }

    // ---------- get / update / delete ----------

    @Test
    void updateAndDeleteByThePatient() throws Exception {
        when(glucoseLogService.update(eq(PATIENT_ID), eq(PATIENT_ID), eq(100L), any(GlucoseLogRequest.class)))
                .thenReturn(glucose(100L, false));

        as(put(GLUCOSE_URL + "/{logId}", PATIENT_ID, 100).contentType(MediaType.APPLICATION_JSON)
                .content(VALID_GLUCOSE), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(100));
        as(delete(GLUCOSE_URL + "/{logId}", PATIENT_ID, 100), PATIENT_ID)
                .andExpect(status().isNoContent());
        verify(glucoseLogService).delete(PATIENT_ID, PATIENT_ID, 100L);
    }

    @Test
    void missingLogIs404() throws Exception {
        when(glucoseLogService.get(PATIENT_ID, PATIENT_ID, 999L))
                .thenThrow(new ResourceNotFoundException("Glucose log not found"));

        as(get(GLUCOSE_URL + "/{logId}", PATIENT_ID, 999), PATIENT_ID)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Glucose log not found"));
    }

    // ---------- the other three log types: same controller pattern ----------

    @Test
    void insulinMealAndActivityLogsCanBeCreated() throws Exception {
        when(insulinLogService.create(eq(PATIENT_ID), eq(PATIENT_ID), any())).thenReturn(CreateResult.created(
                new InsulinLogResponse(1L, PATIENT_ID, new BigDecimal("4.50"), InsulinType.RAPID, InsulinDeliveryMethod.PEN,
                        null, MEASURED, null, InsulinSource.MANUAL, null, null, MEASURED, MEASURED)));
        when(mealLogService.create(eq(PATIENT_ID), eq(PATIENT_ID), any())).thenReturn(CreateResult.created(
                new MealLogResponse(2L, PATIENT_ID, MealType.LUNCH, MEASURED, null, new BigDecimal("45.0"), null, null,
                        null, MealSource.MANUAL, null, null, MEASURED, MEASURED)));
        when(activityLogService.create(eq(PATIENT_ID), eq(PATIENT_ID), any())).thenReturn(CreateResult.created(
                new ActivityLogResponse(3L, PATIENT_ID, "walking", MEASURED, new BigDecimal("30.0"), null, null, null,
                        null, ActivitySource.MANUAL, null, null, MEASURED, MEASURED)));

        as(post("/api/v1/patients/{patientId}/insulin-logs", PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"doseUnits":4.5,"insulinType":"RAPID","deliveryMethod":"PEN",
                         "administeredAt":"2026-10-05T08:30:00Z"}"""), PATIENT_ID)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.doseUnits").value(4.5));
        as(post("/api/v1/patients/{patientId}/meal-logs", PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"mealType\":\"LUNCH\",\"eatenAt\":\"2026-10-05T08:30:00Z\",\"carbsG\":45}"), PATIENT_ID)
                .andExpect(status().isCreated());
        as(post("/api/v1/patients/{patientId}/activity-logs", PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"activityType\":\"walking\",\"startedAt\":\"2026-10-05T08:30:00Z\",\"durationMinutes\":30}"),
                PATIENT_ID)
                .andExpect(status().isCreated());
    }

    @Test
    void numericLimitsOfTheOtherLogTypesAreChecked() throws Exception {
        as(post("/api/v1/patients/{patientId}/insulin-logs", PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"doseUnits\":1.234,\"administeredAt\":\"2026-10-05T08:30:00Z\"}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.doseUnits").value("Dose can have at most 2 decimal places"));
        as(post("/api/v1/patients/{patientId}/meal-logs", PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"mealType\":\"LUNCH\",\"eatenAt\":\"2026-10-05T08:30:00Z\",\"carbsG\":-1}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.carbsG").value("Carbs must be 0 or more"));
        as(post("/api/v1/patients/{patientId}/activity-logs", PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"activityType\":\" \",\"startedAt\":\"2026-10-05T08:30:00Z\",\"avgHeartRate\":300}"),
                PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.activityType").value("Activity type is required"))
                .andExpect(jsonPath("$.errors.avgHeartRate").value("Average heart rate must be at most 260 bpm"));
        verifyNoInteractions(insulinLogService, mealLogService, activityLogService);
    }

    // ---------- AI ----------

    @Test
    void aiParseIsForPatientsOnly() throws Exception {
        as(post("/api/v1/ai/parse").contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"glucose 130\"}"),
                CAREGIVER_ID)
                .andExpect(status().isForbidden());
        verifyNoInteractions(aiService);
    }

    @Test
    void aiParseReturnsTheEntries() throws Exception {
        when(aiService.parse("glucose 130 and 6 units of insulin")).thenReturn(new AiParseResponse("SUCCESS", 2,
                List.of(new AiParseResponse.Entry("LOG_GLUCOSE", "SUCCESS", 130.0, "mg/dL", null, null),
                        new AiParseResponse.Entry("LOG_INSULIN", "SUCCESS", 6.0, "units", null, null)),
                null));

        as(post("/api/v1/ai/parse").contentType(MediaType.APPLICATION_JSON)
                .content("{\"text\":\"glucose 130 and 6 units of insulin\"}"), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resultCount").value(2))
                .andExpect(jsonPath("$.results[1].intent").value("LOG_INSULIN"))
                .andExpect(jsonPath("$.results[1].value").value(6.0));
    }

    @Test
    void aiParseValidatesTheText() throws Exception {
        as(post("/api/v1/ai/parse").contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"   \"}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.text").value("Text is required"));
        as(post("/api/v1/ai/parse").contentType(MediaType.APPLICATION_JSON)
                .content("{\"text\":\"" + "a".repeat(501) + "\"}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.text").value("Text must be at most 500 characters"));
        verifyNoInteractions(aiService);
    }

    @Test
    void aiServiceDownIs503ProblemDetail() throws Exception {
        when(aiService.parse(any())).thenThrow(AiServiceException.unavailable(null));

        as(post("/api/v1/ai/parse").contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"glucose 130\"}"),
                PATIENT_ID)
                .andExpect(status().isServiceUnavailable())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("The AI service is currently unavailable"));
    }

    // ---------- helpers ----------

    private static GlucoseLogResponse glucose(long id, boolean withClientUuid) {
        return new GlucoseLogResponse(id, PATIENT_ID, 125, MEASURED, MealContext.FASTING, GlucoseSource.MANUAL, null,
                withClientUuid ? UUID.fromString("3f1c2a9e-8d7b-4c6a-9e5f-1a2b3c4d5e6f") : null, MEASURED, MEASURED);
    }

    /** Sends the request with a real token signed by the application's JwtEncoder. */
    private ResultActions as(MockHttpServletRequestBuilder request, long userId) throws Exception {
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenFor(userId, roleOf(userId))));
    }

    private String tokenFor(long userId, Role role) {
        User user = new User("u" + userId + "@example.com", "hash", role, "First", "Last",
                LocalDate.of(2000, 1, 15), Gender.OTHER);
        ReflectionTestUtils.setField(user, "id", userId);
        return new JwtService(jwtEncoder, jwtProperties).generateToken(user);
    }

    private static Role roleOf(long id) {
        if (id == ADMIN_ID) {
            return Role.ADMIN;
        }
        if (id == CLINICIAN_ID) {
            return Role.CLINICIAN;
        }
        if (id == CAREGIVER_ID) {
            return Role.CAREGIVER;
        }
        return Role.PATIENT;
    }
}

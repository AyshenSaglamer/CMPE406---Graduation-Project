package com.diamate.backend.api.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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

import com.diamate.backend.api.dto.request.ActivityLogRequest;
import com.diamate.backend.api.dto.request.InsulinLogRequest;
import com.diamate.backend.api.dto.request.MealLogRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.InsulinLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.ActivityIntensity;
import com.diamate.backend.entity.ActivitySource;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.InsulinDeliveryMethod;
import com.diamate.backend.entity.InsulinSource;
import com.diamate.backend.entity.InsulinType;
import com.diamate.backend.entity.MealSource;
import com.diamate.backend.entity.MealType;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.ActivityLogService;
import com.diamate.backend.service.InsulinLogService;
import com.diamate.backend.service.MealLogService;

/**
 * Reading, listing, updating and deleting insulin, meal and activity logs (creating them, and everything about glucose,
 * is in HealthLogWebTest). Real SecurityConfig, real signed tokens, validation and GlobalExceptionHandler; the services
 * are mocks (their rules are tested in InsulinLogServiceTest and MealAndActivityLogServiceTest).
 */
@WebMvcTest(
        controllers = { InsulinLogController.class, MealLogController.class, ActivityLogController.class },
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class LogEndpointsWebTest {

    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final long CAREGIVER_ID = 4;
    private static final long ADMIN_ID = 1;
    private static final Instant AT = Instant.parse("2026-10-05T08:30:00Z");

    private static final String INSULIN_URL = "/api/v1/patients/{patientId}/insulin-logs";
    private static final String MEAL_URL = "/api/v1/patients/{patientId}/meal-logs";
    private static final String ACTIVITY_URL = "/api/v1/patients/{patientId}/activity-logs";

    // The bodies the Flutter app sends (lib/screens/*_entry_screen.dart)
    private static final String VALID_INSULIN = """
            {"doseUnits":4.5,"insulinType":"RAPID","deliveryMethod":"PEN","administeredAt":"2026-10-05T08:30:00Z",
             "source":"MANUAL"}""";
    private static final String VALID_MEAL = """
            {"mealType":"LUNCH","eatenAt":"2026-10-05T08:30:00Z","description":"lentil soup","carbsG":45,"source":"MANUAL"}""";
    private static final String VALID_ACTIVITY = """
            {"activityType":"walking","startedAt":"2026-10-05T08:30:00Z","durationMinutes":30,"intensity":"MODERATE"}""";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private InsulinLogService insulinLogService;

    @MockitoBean
    private MealLogService mealLogService;

    @MockitoBean
    private ActivityLogService activityLogService;

    @MockitoBean
    private UserRepository userRepository;

    // Every test account exists, is active and still has the role written in its token.
    @BeforeEach
    void everyAccountIsActive() {
        when(userRepository.findActiveUserRole(anyLong())).thenAnswer(call -> Optional.of(roleOf(call.getArgument(0))));
    }

    // ---------- the patient: get, list, update, delete ----------

    @Test
    void insulinLogsCanBeReadUpdatedAndDeletedByThePatient() throws Exception {
        when(insulinLogService.list(PATIENT_ID, PATIENT_ID, null, null, 0, 50))
                .thenReturn(new PageResponse<>(List.of(insulin(10L)), 0, 50, 1, 1));
        when(insulinLogService.get(PATIENT_ID, PATIENT_ID, 10L)).thenReturn(insulin(10L));
        when(insulinLogService.update(eq(PATIENT_ID), eq(PATIENT_ID), eq(10L), any(InsulinLogRequest.class)))
                .thenReturn(insulin(10L));

        as(get(INSULIN_URL, PATIENT_ID), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].doseUnits").value(4.5))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.totalPages").value(1));
        as(get(INSULIN_URL + "/{logId}", PATIENT_ID, 10), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.insulinType").value("RAPID"));
        as(put(INSULIN_URL + "/{logId}", PATIENT_ID, 10).contentType(MediaType.APPLICATION_JSON).content(VALID_INSULIN),
                PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(10));
        as(delete(INSULIN_URL + "/{logId}", PATIENT_ID, 10), PATIENT_ID)
                .andExpect(status().isNoContent());
        verify(insulinLogService).delete(PATIENT_ID, PATIENT_ID, 10L);
    }

    @Test
    void mealLogsCanBeReadUpdatedAndDeletedByThePatient() throws Exception {
        when(mealLogService.list(PATIENT_ID, PATIENT_ID, null, null, 0, 50))
                .thenReturn(new PageResponse<>(List.of(meal(20L)), 0, 50, 1, 1));
        when(mealLogService.get(PATIENT_ID, PATIENT_ID, 20L)).thenReturn(meal(20L));
        when(mealLogService.update(eq(PATIENT_ID), eq(PATIENT_ID), eq(20L), any(MealLogRequest.class)))
                .thenReturn(meal(20L));

        as(get(MEAL_URL, PATIENT_ID), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].carbsG").value(45.0));
        as(get(MEAL_URL + "/{logId}", PATIENT_ID, 20), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mealType").value("LUNCH"));
        as(put(MEAL_URL + "/{logId}", PATIENT_ID, 20).contentType(MediaType.APPLICATION_JSON).content(VALID_MEAL),
                PATIENT_ID)
                .andExpect(status().isOk());
        as(delete(MEAL_URL + "/{logId}", PATIENT_ID, 20), PATIENT_ID)
                .andExpect(status().isNoContent());
        verify(mealLogService).delete(PATIENT_ID, PATIENT_ID, 20L);
    }

    @Test
    void activityLogsCanBeReadUpdatedAndDeletedByThePatient() throws Exception {
        when(activityLogService.list(PATIENT_ID, PATIENT_ID, null, null, 0, 50))
                .thenReturn(new PageResponse<>(List.of(activity(30L)), 0, 50, 1, 1));
        when(activityLogService.get(PATIENT_ID, PATIENT_ID, 30L)).thenReturn(activity(30L));
        when(activityLogService.update(eq(PATIENT_ID), eq(PATIENT_ID), eq(30L), any(ActivityLogRequest.class)))
                .thenReturn(activity(30L));

        as(get(ACTIVITY_URL, PATIENT_ID), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].activityType").value("walking"));
        as(get(ACTIVITY_URL + "/{logId}", PATIENT_ID, 30), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source").value("MANUAL"));
        as(put(ACTIVITY_URL + "/{logId}", PATIENT_ID, 30).contentType(MediaType.APPLICATION_JSON).content(VALID_ACTIVITY),
                PATIENT_ID)
                .andExpect(status().isOk());
        as(delete(ACTIVITY_URL + "/{logId}", PATIENT_ID, 30), PATIENT_ID)
                .andExpect(status().isNoContent());
        verify(activityLogService).delete(PATIENT_ID, PATIENT_ID, 30L);
    }

    @Test
    void listParametersArePassedOnForEveryType() throws Exception {
        Instant from = Instant.parse("2026-10-01T00:00:00Z");
        Instant to = Instant.parse("2026-10-05T00:00:00Z");
        when(insulinLogService.list(PATIENT_ID, PATIENT_ID, from, to, 1, 200)).thenReturn(new PageResponse<>(List.of(), 1, 200, 0, 0));
        when(mealLogService.list(PATIENT_ID, PATIENT_ID, from, to, 1, 200)).thenReturn(new PageResponse<>(List.of(), 1, 200, 0, 0));
        when(activityLogService.list(PATIENT_ID, PATIENT_ID, from, to, 1, 200)).thenReturn(new PageResponse<>(List.of(), 1, 200, 0, 0));

        // What the app's LogStore sends: page size 200, UTC times
        for (String url : new String[] { INSULIN_URL, MEAL_URL, ACTIVITY_URL }) {
            as(get(url, PATIENT_ID).param("from", "2026-10-01T00:00:00.000Z").param("to", "2026-10-05T00:00:00.000Z")
                    .param("page", "1").param("size", "200"), PATIENT_ID)
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.page").value(1))
                    .andExpect(jsonPath("$.items").isEmpty());
        }
    }

    // ---------- the care team: read only ----------

    @Test
    void careTeamCanReadWhenTheServiceAllowsIt() throws Exception {
        when(insulinLogService.get(CLINICIAN_ID, PATIENT_ID, 10L)).thenReturn(insulin(10L));
        when(mealLogService.get(CAREGIVER_ID, PATIENT_ID, 20L)).thenReturn(meal(20L));
        when(activityLogService.get(CLINICIAN_ID, PATIENT_ID, 30L)).thenReturn(activity(30L));

        as(get(INSULIN_URL + "/{logId}", PATIENT_ID, 10), CLINICIAN_ID).andExpect(status().isOk());
        as(get(MEAL_URL + "/{logId}", PATIENT_ID, 20), CAREGIVER_ID).andExpect(status().isOk());
        as(get(ACTIVITY_URL + "/{logId}", PATIENT_ID, 30), CLINICIAN_ID).andExpect(status().isOk());
    }

    @Test
    void onlyPatientsCanUpdateOrDelete() throws Exception {
        String[][] typeUrlAndBody = { { INSULIN_URL, VALID_INSULIN }, { MEAL_URL, VALID_MEAL },
                { ACTIVITY_URL, VALID_ACTIVITY } };
        for (long id : new long[] { CLINICIAN_ID, CAREGIVER_ID, ADMIN_ID }) {
            for (String[] type : typeUrlAndBody) {
                as(put(type[0] + "/{logId}", PATIENT_ID, 1).contentType(MediaType.APPLICATION_JSON).content(type[1]), id)
                        .andExpect(status().isForbidden())
                        .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
                as(delete(type[0] + "/{logId}", PATIENT_ID, 1), id)
                        .andExpect(status().isForbidden());
            }
        }
        verifyNoInteractions(insulinLogService, mealLogService, activityLogService);
    }

    // ---------- 404 and 400 ----------

    @Test
    void missingLogsAre404ProblemDetails() throws Exception {
        when(insulinLogService.get(PATIENT_ID, PATIENT_ID, 999L)).thenThrow(new ResourceNotFoundException("Insulin log not found"));
        when(mealLogService.update(eq(PATIENT_ID), eq(PATIENT_ID), eq(999L), any()))
                .thenThrow(new ResourceNotFoundException("Meal log not found"));
        doThrow(new ResourceNotFoundException("Activity log not found"))
                .when(activityLogService).delete(PATIENT_ID, PATIENT_ID, 999L);

        as(get(INSULIN_URL + "/{logId}", PATIENT_ID, 999), PATIENT_ID)
                .andExpect(status().isNotFound())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Insulin log not found"));
        as(put(MEAL_URL + "/{logId}", PATIENT_ID, 999).contentType(MediaType.APPLICATION_JSON).content(VALID_MEAL), PATIENT_ID)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Meal log not found"));
        as(delete(ACTIVITY_URL + "/{logId}", PATIENT_ID, 999), PATIENT_ID)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Activity log not found"));
    }

    @Test
    void careTeamWithoutPermissionGets404() throws Exception {
        // e.g. the demo caregiver and patient08: glucose is shared, meals are not
        when(mealLogService.list(CAREGIVER_ID, PATIENT_ID, null, null, 0, 50))
                .thenThrow(new ResourceNotFoundException("Patient not found"));

        as(get(MEAL_URL, PATIENT_ID), CAREGIVER_ID)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("Patient not found"));
    }

    @Test
    void invalidUpdatesAre400WithAnErrorPerFieldAndReachNoService() throws Exception {
        as(put(INSULIN_URL + "/{logId}", PATIENT_ID, 10).contentType(MediaType.APPLICATION_JSON)
                .content("{\"doseUnits\":0,\"administeredAt\":\"2026-10-05T08:30:00Z\"}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.doseUnits").value("Dose must be greater than 0"));
        as(put(MEAL_URL + "/{logId}", PATIENT_ID, 20).contentType(MediaType.APPLICATION_JSON)
                .content("{\"eatenAt\":\"2026-10-05T08:30:00Z\",\"carbsG\":-1}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.mealType").value("Meal type is required"))
                .andExpect(jsonPath("$.errors.carbsG").value("Carbs must be 0 or more"));
        as(put(ACTIVITY_URL + "/{logId}", PATIENT_ID, 30).contentType(MediaType.APPLICATION_JSON)
                .content("{\"activityType\":\" \",\"startedAt\":\"2026-10-05T08:30:00Z\",\"intensity\":\"EXTREME\"}"),
                PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.intensity").exists());
        verifyNoInteractions(insulinLogService, mealLogService, activityLogService);
    }

    @Test
    void nonNumericLogIdIs400() throws Exception {
        as(get(INSULIN_URL + "/abc", PATIENT_ID), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.logId").value("Must be a whole number"));
        verifyNoInteractions(insulinLogService);
    }

    // ---------- helpers ----------

    private static InsulinLogResponse insulin(long id) {
        return new InsulinLogResponse(id, PATIENT_ID, new BigDecimal("4.50"), InsulinType.RAPID, InsulinDeliveryMethod.PEN,
                null, AT, null, InsulinSource.MANUAL, null, null, AT, AT);
    }

    private static MealLogResponse meal(long id) {
        return new MealLogResponse(id, PATIENT_ID, MealType.LUNCH, AT, "lentil soup", new BigDecimal("45.0"), null, null,
                null, MealSource.MANUAL, null, null, AT, AT);
    }

    private static ActivityLogResponse activity(long id) {
        return new ActivityLogResponse(id, PATIENT_ID, "walking", AT, new BigDecimal("30.0"), null, null, null,
                ActivityIntensity.MODERATE, ActivitySource.MANUAL, null, null, AT, AT);
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

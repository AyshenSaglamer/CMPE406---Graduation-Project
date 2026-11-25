package com.diamate.backend.api.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
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

import com.diamate.backend.config.JsonStrictnessConfig;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.CareRelationshipService;
import com.diamate.backend.service.CreateResult;
import com.diamate.backend.service.GlucoseLogService;
import com.diamate.backend.service.UserService;

/**
 * A value of the wrong JSON type is a 400 naming the field, never silently converted (QA scan, week 3): a number is
 * not a time, a true/false, an enum or a text; empty text is not a number, a true/false or a UUID; a plain number in
 * the query string is not a time. Uses the real JSON configuration (application.yml, JsonStrictnessConfig,
 * StrictInstantDeserializer, TextDeserializer, StrictInstantFormatConfig).
 */
@WebMvcTest(
        controllers = { GlucoseLogController.class, AdminController.class, CareRelationshipController.class },
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class,
        JsonStrictnessConfig.class })
class StrictJsonWebTest {

    private static final long PATIENT_ID = 5;
    private static final long ADMIN_ID = 1;
    private static final String GLUCOSE_URL = "/api/v1/patients/5/glucose-logs";
    private static final String ISO_MESSAGE = "Must be an ISO-8601 date-time, e.g. 2026-10-05T08:30:00Z";
    private static final Map<Long, Role> ROLES = Map.of(PATIENT_ID, Role.PATIENT, ADMIN_ID, Role.ADMIN);

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private GlucoseLogService glucoseLogService;

    @MockitoBean
    private UserService userService;

    @MockitoBean
    private CareRelationshipService careRelationshipService;

    @MockitoBean
    private UserRepository userRepository;

    @BeforeEach
    void accountsAreActive() {
        when(userRepository.findRoleForOpenSession(anyLong(), any(), any()))
                .thenAnswer(call -> Optional.ofNullable(ROLES.get((Long) call.getArgument(0))));
        when(glucoseLogService.create(anyLong(), anyLong(), any())).thenReturn(CreateResult.existing(null));
    }

    @Test
    void aValidBodyStillPasses() throws Exception {
        glucose("""
                {"glucoseValue":120,"measurementTime":"2026-10-05T11:30:00+03:00","mealContext":"FASTING",
                 "notes":"ok","source":"MANUAL","clientUuid":null}""")
                .andExpect(status().isOk()); // existing(null) from the mock = 200

        verify(glucoseLogService).create(eq(PATIENT_ID), eq(PATIENT_ID), any());
    }

    @ParameterizedTest
    @ValueSource(strings = { "0", "1731830400", "1.5", "-1", "true" })
    void aNumberIsNotATime(String value) throws Exception {
        // 0 used to be saved as 1970-01-01.
        glucose("{\"glucoseValue\":120,\"measurementTime\":" + value + "}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.measurementTime").value(ISO_MESSAGE));
        verifyNoInteractions(glucoseLogService);
    }

    @ParameterizedTest
    @ValueSource(strings = { "0", "1", "-1" })
    void aNumberIsNotAnEnum(String value) throws Exception {
        // "source": 0 used to mean MANUAL, the first constant.
        glucose("{\"glucoseValue\":120,\"measurementTime\":\"2026-10-05T08:30:00Z\",\"source\":" + value + "}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.source").value("Must be one of: MANUAL, AI_ASSISTANT"));
        verifyNoInteractions(glucoseLogService);
    }

    @ParameterizedTest
    @ValueSource(strings = { "42", "true", "1.5", "{}", "[\"a\"]" })
    void onlyAJsonStringIsText(String value) throws Exception {
        glucose("{\"glucoseValue\":120,\"measurementTime\":\"2026-10-05T08:30:00Z\",\"notes\":" + value + "}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.notes").value("Must be text"));
        verifyNoInteractions(glucoseLogService);
    }

    @ParameterizedTest
    @ValueSource(strings = { "\"120\"", "\"\"", "\" \"", "true" })
    void textIsNotANumber(String value) throws Exception {
        glucose("{\"glucoseValue\":" + value + ",\"measurementTime\":\"2026-10-05T08:30:00Z\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.glucoseValue").value("Must be a whole number"));
        verifyNoInteractions(glucoseLogService);
    }

    @ParameterizedTest
    @ValueSource(strings = { "\"\"", "\" \"", "\"\\u0000\"" })
    void emptyTextIsNotAUuid(String value) throws Exception {
        glucose("{\"glucoseValue\":120,\"measurementTime\":\"2026-10-05T08:30:00Z\",\"clientUuid\":" + value + "}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.clientUuid").value("Must be a UUID"));
        verifyNoInteractions(glucoseLogService);
    }

    @ParameterizedTest
    @ValueSource(strings = { "0", "1", "-1", "\"false\"", "\"\"", "\" \"" })
    void aNumberOrTextDoesNotSwitchAnAccount(String value) throws Exception {
        // {"active": 0} used to switch the account off.
        as(ADMIN_ID, patch("/api/v1/admin/users/9/status").contentType(MediaType.APPLICATION_JSON)
                .content("{\"active\":" + value + "}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.active").value("Must be true or false"));
        verifyNoInteractions(userService);
    }

    @ParameterizedTest
    @ValueSource(strings = { "0", "-1", "\"\"", "\" \"", "\"yes\"" })
    void aPermissionIsTrueOrFalse(String value) throws Exception {
        // "canViewMeals": "" used to be read as null, i.e. "leave unchanged".
        as(PATIENT_ID, patch("/api/v1/care-relationships/70").contentType(MediaType.APPLICATION_JSON)
                .content("{\"canViewMeals\":" + value + "}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.canViewMeals").value("Must be true or false"));
        verifyNoInteractions(careRelationshipService);
    }

    @Test
    void nullStillMeansNotSent() throws Exception {
        as(PATIENT_ID, patch("/api/v1/care-relationships/70").contentType(MediaType.APPLICATION_JSON)
                .content("{\"canViewMeals\":null,\"expiresAt\":null}"))
                .andExpect(status().isOk());
    }

    @ParameterizedTest
    @ValueSource(strings = { "0", "1731830400000", "2026", "2026-10-05", "yesterday" })
    void aQueryTimeIsIso8601Only(String value) throws Exception {
        // ?from=0 used to mean 1970-01-01 (milliseconds since 1970).
        as(PATIENT_ID, get(GLUCOSE_URL).param("from", value))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.from").exists());
        verifyNoInteractions(glucoseLogService);
    }

    @Test
    void anIsoQueryTimeWithAnOffsetIsAccepted() throws Exception {
        as(PATIENT_ID, get(GLUCOSE_URL).param("from", "2026-10-05T11:30:00+03:00")).andExpect(status().isOk());

        verify(glucoseLogService).list(PATIENT_ID, PATIENT_ID, Instant.parse("2026-10-05T08:30:00Z"), null, 0, 50);
    }

    private ResultActions glucose(String body) throws Exception {
        return as(PATIENT_ID, post(GLUCOSE_URL).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions as(long userId, MockHttpServletRequestBuilder request) throws Exception {
        User user = new User("First", "Last", LocalDate.of(2000, 1, 15), Gender.OTHER, ROLES.get(userId),
                userId + "@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", userId);
        String token = new JwtService(jwtEncoder, jwtProperties, Clock.systemUTC()).generateToken(user, java.util.UUID.randomUUID());
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }
}

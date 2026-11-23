package com.diamate.backend.api.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.is;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
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

import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.MealContext;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.AiEntryService;
import com.diamate.backend.service.CreateResult;
import com.diamate.backend.service.GlucoseLogService;

/**
 * Week 2 Day 5: request bodies that try something unusual. Real SecurityConfig, real tokens, the real JSON settings of
 * application.yml (strict duplicate detection, no float for an int) and GlobalExceptionHandler; the services are mocks.
 */
@WebMvcTest(
        controllers = { GlucoseLogController.class, AiEntryController.class },
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class InputHardeningWebTest {

    private static final long PATIENT_ID = 5;
    private static final String GLUCOSE_URL = "/api/v1/patients/{patientId}/glucose-logs";
    private static final String AI_ENTRIES_URL = "/api/v1/patients/{patientId}/ai-entries";
    private static final Instant MEASURED = Instant.parse("2026-10-05T08:30:00Z");
    private static final String TOO_LARGE = "Value must be at most 100000";
    private static final String TOO_MANY_DIGITS = "Value can have at most 6 digits before and 3 after the decimal point";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private GlucoseLogService glucoseLogService;

    @MockitoBean
    private AiEntryService aiEntryService;

    @MockitoBean
    private UserRepository userRepository;

    @BeforeEach
    void thePatientIsActive() {
        when(userRepository.findActiveUserRole(anyLong())).thenReturn(Optional.of(Role.PATIENT));
    }

    // ---------- S-1: a short number that would expand into a huge one ----------

    @Test
    void aHugeExponentIsRefusedBeforeAnyConversion() throws Exception {
        long start = System.nanoTime();

        // 11 characters of JSON; as plain text this number has a billion digits.
        asPatient(post(AI_ENTRIES_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"entries\":[{\"intent\":\"LOG_ACTIVITY\",\"value\":1e999999999,\"unit\":\"km\",\"activity\":\"ran\"}]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors['entries[0].value']").value(anyOf(
                        is(TOO_LARGE), is(TOO_MANY_DIGITS)))); // both rules are broken; either one is reported

        assertThat(Duration.ofNanos(System.nanoTime() - start)).isLessThan(Duration.ofSeconds(2));
        verifyNoInteractions(aiEntryService);
    }

    @Test
    void valuesAboveTheLimitAreRefused() throws Exception {
        asPatient(post(AI_ENTRIES_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"entries\":[{\"intent\":\"LOG_ACTIVITY\",\"value\":1e6,\"unit\":\"km\",\"activity\":\"ran\"}]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors['entries[0].value']").value(anyOf(is(TOO_LARGE), is(TOO_MANY_DIGITS))));
        verifyNoInteractions(aiEntryService);
    }

    @Test
    void aNumberWithThousandsOfDigitsIsRefused() throws Exception {
        // Jackson's default limit is 1000 characters per number: longer ones are never turned into a BigDecimal.
        asPatient(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"glucoseValue\":" + "9".repeat(2000) + ",\"measurementTime\":\"2026-10-05T08:30:00Z\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(glucoseLogService);
    }

    // ---------- the same field twice ----------

    @Test
    void aFieldSentTwiceIsRefusedAndNamed() throws Exception {
        // "Last one wins" would let a proxy or a log see 120 while the backend saves 600.
        asPatient(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"glucoseValue\":120,\"glucoseValue\":600,\"measurementTime\":\"2026-10-05T08:30:00Z\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.glucoseValue").value("Must appear only once"));
        verifyNoInteractions(glucoseLogService);
    }

    // ---------- fields the client must not set ----------

    @Test
    void serverSideFieldsInTheBodyAreIgnored() throws Exception {
        when(glucoseLogService.create(eq(PATIENT_ID), eq(PATIENT_ID), any())).thenReturn(CreateResult.created(
                new GlucoseLogResponse(100L, PATIENT_ID, 125, MEASURED, MealContext.FASTING, GlucoseSource.MANUAL, null,
                        null, MEASURED, MEASURED)));

        // id, patientId, enteredBy, deletedAt, createdAt: none of them is part of the request, so none can be set.
        asPatient(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content("""
                {"glucoseValue":125,"measurementTime":"2026-10-05T08:30:00Z","mealContext":"FASTING",
                 "id":999,"patientId":8,"enteredBy":2,"deletedAt":"2026-10-05T09:00:00Z","createdAt":"2020-01-01T00:00:00Z"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(100))
                .andExpect(jsonPath("$.patientId").value(PATIENT_ID));

        // The patient id comes from the URL (checked against the token in the service), not from the body.
        ArgumentCaptor<GlucoseLogRequest> request = ArgumentCaptor.forClass(GlucoseLogRequest.class);
        verify(glucoseLogService).create(eq(PATIENT_ID), eq(PATIENT_ID), request.capture());
        assertThat(request.getValue()).isEqualTo(
                new GlucoseLogRequest(125, MEASURED, MealContext.FASTING, null, null, null));
    }

    @Test
    void onlyTheSourcesAClientMaySetAreAccepted() throws Exception {
        // CGM, METER, PUMP, IMPORT ... come from device integrations, never from a request.
        asPatient(post(GLUCOSE_URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"glucoseValue\":125,\"measurementTime\":\"2026-10-05T08:30:00Z\",\"source\":\"CGM\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.source").value("Must be one of: " + EntrySource.MANUAL + ", " + EntrySource.AI_ASSISTANT));
        verifyNoInteractions(glucoseLogService);
    }

    // ---------- helpers ----------

    private ResultActions asPatient(MockHttpServletRequestBuilder request) throws Exception {
        User user = new User("First", "Last", LocalDate.of(2000, 1, 15), Gender.OTHER, Role.PATIENT, "p@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", PATIENT_ID);
        String token = new JwtService(jwtEncoder, jwtProperties, Clock.systemUTC()).generateToken(user);
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }
}

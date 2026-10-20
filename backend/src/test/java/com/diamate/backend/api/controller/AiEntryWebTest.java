package com.diamate.backend.api.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Collections;
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

import com.diamate.backend.api.dto.request.AiEntriesRequest;
import com.diamate.backend.api.dto.request.AiIntent;
import com.diamate.backend.api.dto.response.AiEntriesResponse;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.AiEntryService;

/**
 * POST /patients/{id}/ai-entries with the real SecurityConfig, real signed tokens, validation and
 * GlobalExceptionHandler. How entries become logs is tested in AiEntryServiceTest.
 */
@WebMvcTest(
        controllers = AiEntryController.class,
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class AiEntryWebTest {

    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final long CAREGIVER_ID = 4;
    private static final long ADMIN_ID = 1;
    private static final String URL = "/api/v1/patients/{patientId}/ai-entries";
    private static final Instant AT = Instant.parse("2026-10-13T09:00:00Z");

    // Entries copied from an /ai/parse answer, as the app sends them after the patient confirmed: value 125.0, not 125.
    private static final String CONFIRMED = """
            {"entries":[
              {"intent":"LOG_GLUCOSE","value":125.0,"unit":"mg/dL","clientUuid":"3f1c2a9e-8d7b-4c6a-9e5f-1a2b3c4d5e6f"},
              {"intent":"LOG_INSULIN","value":6.0,"unit":"units"},
              {"intent":"LOG_ACTIVITY","value":30.0,"unit":"minutes","activity":"walked"}]}""";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private AiEntryService aiEntryService;

    @MockitoBean
    private UserRepository userRepository;

    // Every test account exists, is active and still has the role written in its token.
    @BeforeEach
    void everyAccountIsActive() {
        when(userRepository.findActiveUserRole(anyLong())).thenAnswer(call -> Optional.of(roleOf(call.getArgument(0))));
    }

    @Test
    void confirmedEntriesAreSavedWith201() throws Exception {
        when(aiEntryService.save(eq(PATIENT_ID), eq(PATIENT_ID), any())).thenReturn(response(true));

        as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(CONFIRMED), PATIENT_ID)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.savedCount").value(1))
                .andExpect(jsonPath("$.saved[0].intent").value("LOG_GLUCOSE"))
                .andExpect(jsonPath("$.saved[0].created").value(true))
                .andExpect(jsonPath("$.saved[0].log.glucoseValue").value(125))
                .andExpect(jsonPath("$.saved[0].log.source").value("AI_ASSISTANT"));

        ArgumentCaptor<AiEntriesRequest> request = ArgumentCaptor.forClass(AiEntriesRequest.class);
        verify(aiEntryService).save(eq(PATIENT_ID), eq(PATIENT_ID), request.capture());
        assertThat(request.getValue().entries())
                .extracting(AiEntriesRequest.Entry::intent)
                .containsExactly(AiIntent.LOG_GLUCOSE, AiIntent.LOG_INSULIN, AiIntent.LOG_ACTIVITY);
    }

    @Test
    void entriesThatWereAllSavedBeforeGet200() throws Exception {
        when(aiEntryService.save(eq(PATIENT_ID), eq(PATIENT_ID), any())).thenReturn(response(false));

        as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(CONFIRMED), PATIENT_ID)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.saved[0].created").value(false));
    }

    @Test
    void onlyPatientsCanSave() throws Exception {
        for (long id : new long[] { CLINICIAN_ID, CAREGIVER_ID, ADMIN_ID }) {
            as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(CONFIRMED), id)
                    .andExpect(status().isForbidden())
                    .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
        }
        verifyNoInteractions(aiEntryService);
    }

    @Test
    void theRequestShapeIsCheckedPerEntry() throws Exception {
        as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content("{\"entries\":[]}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.entries").value("At least one entry is required"));
        // UNKNOWN parts are never returned by /ai/parse, so they cannot be saved either.
        as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"entries\":[{\"intent\":\"UNKNOWN\",\"value\":1}]}"), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors['entries[0].intent']")
                        .value("Must be one of: LOG_GLUCOSE, LOG_INSULIN, LOG_MEAL, LOG_ACTIVITY"));
        // A MISSING_VALUE answer has no value: the patient must type it before saving.
        as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON)
                .content("{\"entries\":[{\"intent\":\"LOG_GLUCOSE\",\"value\":125},{\"intent\":\"LOG_MEAL\",\"unit\":\"grams\"}]}"),
                PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors['entries[1].value']").value("Value is required"));
        verifyNoInteractions(aiEntryService);
    }

    @Test
    void atMostTenEntriesAtOnce() throws Exception {
        String entry = "{\"intent\":\"LOG_GLUCOSE\",\"value\":120}";
        String eleven = "{\"entries\":[" + String.join(",", Collections.nCopies(11, entry)) + "]}";

        as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(eleven), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.entries").value("At most 10 entries can be saved at once"));
        verifyNoInteractions(aiEntryService);
    }

    @Test
    void aRuleBrokenInTheServiceNamesTheEntry() throws Exception {
        when(aiEntryService.save(eq(PATIENT_ID), eq(PATIENT_ID), any()))
                .thenThrow(new InvalidFieldException("entries[1].value", "Dose must be at most 300 units"));

        as(post(URL, PATIENT_ID).contentType(MediaType.APPLICATION_JSON).content(CONFIRMED), PATIENT_ID)
                .andExpect(status().isBadRequest())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.errors['entries[1].value']").value("Dose must be at most 300 units"));
    }

    // ---------- helpers ----------

    private static AiEntriesResponse response(boolean created) {
        GlucoseLogResponse glucose = new GlucoseLogResponse(11L, PATIENT_ID, 125, AT, null, GlucoseSource.AI_ASSISTANT,
                null, null, AT, AT);
        return new AiEntriesResponse(1, List.of(new AiEntriesResponse.Saved(AiIntent.LOG_GLUCOSE, 11L, created, glucose)));
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

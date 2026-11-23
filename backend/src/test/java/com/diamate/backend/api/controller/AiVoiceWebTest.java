package com.diamate.backend.api.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.AbstractMockHttpServletRequestBuilder;

import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.api.dto.response.AiVoiceResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AiServiceException;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.AiService;

/**
 * POST /api/v1/ai/voice: a recording as multipart/form-data, only for patients. The checks of the file are in
 * AiService (AiServiceTest); here: the HTTP shape, the role rule and how errors are answered.
 */
@WebMvcTest(
        controllers = AiController.class,
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class AiVoiceWebTest {

    private static final String URL = "/api/v1/ai/voice";
    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final Map<Long, Role> ROLES = Map.of(PATIENT_ID, Role.PATIENT, CLINICIAN_ID, Role.CLINICIAN);
    private static final MockMultipartFile RECORDING =
            new MockMultipartFile("audio", "r.m4a", "audio/mp4", new byte[] { 1, 2, 3 });

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private AiService aiService;

    @MockitoBean
    private UserRepository userRepository;

    @BeforeEach
    void accountsAreActive() {
        when(userRepository.findActiveUserRole(anyLong()))
                .thenAnswer(call -> Optional.ofNullable(ROLES.get((Long) call.getArgument(0))));
    }

    @Test
    void thePatientGetsTheTranscriptAndWhatWasUnderstood() throws Exception {
        when(aiService.parseVoice(any())).thenReturn(new AiVoiceResponse("SUCCESS", "my glucose is 145", 1,
                List.of(new AiParseResponse.Entry("LOG_GLUCOSE", "SUCCESS", 145.0, "mg/dL", null, null)), null));

        as(PATIENT_ID, multipart(URL).file(RECORDING))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.transcript").value("my glucose is 145"))
                .andExpect(jsonPath("$.resultCount").value(1))
                .andExpect(jsonPath("$.results[0].intent").value("LOG_GLUCOSE"));
    }

    @Test
    void onlyPatientsMayUploadARecording() throws Exception {
        as(CLINICIAN_ID, multipart(URL).file(RECORDING)).andExpect(status().isForbidden());
        mockMvc.perform(multipart(URL).file(RECORDING)).andExpect(status().isUnauthorized());
        verifyNoInteractions(aiService);
    }

    @Test
    void theAudioFieldIsRequired() throws Exception {
        as(PATIENT_ID, multipart(URL).file(new MockMultipartFile("file", "r.m4a", "audio/mp4", new byte[] { 1 })))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(aiService);
    }

    @Test
    void jsonInsteadOfAFileIs415() throws Exception {
        as(PATIENT_ID, post(URL).contentType(MediaType.APPLICATION_JSON).content("{\"audio\":\"AAAA\"}"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(aiService);
    }

    @Test
    void aBadFileIs400NamingTheField() throws Exception {
        when(aiService.parseVoice(any()))
                .thenThrow(new InvalidFieldException("audio", "The recording must be a WAV, MP3, M4A, WEBM or OGG file"));

        as(PATIENT_ID, multipart(URL).file(RECORDING))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.audio").value("The recording must be a WAV, MP3, M4A, WEBM or OGG file"));
    }

    @Test
    void speechTheAiServiceCouldNotUseIs422WithItsReason() throws Exception {
        when(aiService.parseVoice(any()))
                .thenThrow(AiServiceException.unprocessable("Transcript cannot be empty.", null));

        as(PATIENT_ID, multipart(URL).file(RECORDING))
                .andExpect(status().isUnprocessableContent())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Transcript cannot be empty."));
    }

    private ResultActions as(long userId, AbstractMockHttpServletRequestBuilder<?> request) throws Exception {
        User user = new User("First", "Last", LocalDate.of(2000, 1, 15), Gender.OTHER, ROLES.get(userId),
                userId + "@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", userId);
        String token = new JwtService(jwtEncoder, jwtProperties, Clock.systemUTC()).generateToken(user);
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }
}

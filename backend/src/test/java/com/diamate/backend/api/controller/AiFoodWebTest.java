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

import java.math.BigDecimal;
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

import com.diamate.backend.api.dto.response.FoodRecognitionResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.FoodVisionException;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.AiService;
import com.diamate.backend.service.FoodRecognitionService;

/**
 * POST /api/v1/ai/food: a meal photo as multipart/form-data, only for patients. The checks of the photo are in
 * FoodRecognitionService (FoodRecognitionServiceTest); here: the HTTP shape, the role rule and how errors are answered.
 */
@WebMvcTest(
        controllers = AiController.class,
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class AiFoodWebTest {

    private static final String URL = "/api/v1/ai/food";
    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final long CAREGIVER_ID = 3;
    private static final Map<Long, Role> ROLES = Map.of(PATIENT_ID, Role.PATIENT, CLINICIAN_ID, Role.CLINICIAN,
            CAREGIVER_ID, Role.CAREGIVER);
    private static final MockMultipartFile PHOTO =
            new MockMultipartFile("image", "meal.jpg", "image/jpeg", new byte[] { (byte) 0xFF, (byte) 0xD8, (byte) 0xFF });

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private AiService aiService;

    @MockitoBean
    private FoodRecognitionService foodRecognitionService;

    @MockitoBean
    private UserRepository userRepository;

    @BeforeEach
    void accountsAreActive() {
        when(userRepository.findActiveUserRole(anyLong()))
                .thenAnswer(call -> Optional.ofNullable(ROLES.get((Long) call.getArgument(0))));
    }

    @Test
    void thePatientGetsTheGuessesWithApproximateNutrition() throws Exception {
        when(foodRecognitionService.recognize(any())).thenReturn(new FoodRecognitionResponse("ResNet50", false, true,
                List.of(new FoodRecognitionResponse.Prediction("pizza", "Pizza", 0.91, 76L, new BigDecimal("266.0"),
                        new BigDecimal("33.0"), new BigDecimal("200.0"), new BigDecimal("66.0"), false)),
                "Photo recognition can be wrong."));

        as(PATIENT_ID, multipart(URL).file(PHOTO))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.model").value("ResNet50"))
                .andExpect(jsonPath("$.requiresConfirmation").value(true))
                .andExpect(jsonPath("$.lowConfidence").value(false))
                .andExpect(jsonPath("$.predictions[0].food").value("pizza"))
                .andExpect(jsonPath("$.predictions[0].displayName").value("Pizza"))
                .andExpect(jsonPath("$.predictions[0].confidence").value(0.91))
                .andExpect(jsonPath("$.predictions[0].carbsGPerServing").value(66.0))
                .andExpect(jsonPath("$.predictions[0].nutritionVerified").value(false));
    }

    @Test
    void onlyPatientsMayUploadAPhoto() throws Exception {
        as(CLINICIAN_ID, multipart(URL).file(PHOTO)).andExpect(status().isForbidden());
        as(CAREGIVER_ID, multipart(URL).file(PHOTO)).andExpect(status().isForbidden());
        mockMvc.perform(multipart(URL).file(PHOTO)).andExpect(status().isUnauthorized());
        verifyNoInteractions(foodRecognitionService);
    }

    @Test
    void theImageFieldIsRequired() throws Exception {
        as(PATIENT_ID, multipart(URL).file(new MockMultipartFile("file", "meal.jpg", "image/jpeg", new byte[] { 1 })))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(foodRecognitionService);
    }

    @Test
    void jsonInsteadOfAFileIs415() throws Exception {
        as(PATIENT_ID, post(URL).contentType(MediaType.APPLICATION_JSON).content("{\"image\":\"AAAA\"}"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(foodRecognitionService);
    }

    @Test
    void aBadFileIs400NamingTheField() throws Exception {
        when(foodRecognitionService.recognize(any()))
                .thenThrow(new InvalidFieldException("image", "The image must be a JPG, PNG or WEBP file"));

        as(PATIENT_ID, multipart(URL).file(PHOTO))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.image").value("The image must be a JPG, PNG or WEBP file"));
    }

    @Test
    void serviceErrorsAreProblemJsonWithTheirStatus() throws Exception {
        when(foodRecognitionService.recognize(any()))
                .thenThrow(FoodVisionException.unavailable(null))
                .thenThrow(FoodVisionException.unusableImage("Invalid or corrupted image file.", null))
                .thenThrow(FoodVisionException.badResponse(null));

        as(PATIENT_ID, multipart(URL).file(PHOTO))
                .andExpect(status().isServiceUnavailable())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("The food recognition service is currently unavailable"));
        as(PATIENT_ID, multipart(URL).file(PHOTO))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.detail").value("Invalid or corrupted image file."));
        as(PATIENT_ID, multipart(URL).file(PHOTO))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.detail").value("The food recognition service returned an invalid response"));
    }

    private ResultActions as(long userId, AbstractMockHttpServletRequestBuilder<?> request) throws Exception {
        User user = new User("First", "Last", LocalDate.of(2000, 1, 15), Gender.OTHER, ROLES.get(userId),
                userId + "@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", userId);
        String token = new JwtService(jwtEncoder, jwtProperties, Clock.systemUTC()).generateToken(user);
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }
}

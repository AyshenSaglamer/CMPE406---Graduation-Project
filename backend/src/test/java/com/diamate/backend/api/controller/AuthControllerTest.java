package com.diamate.backend.api.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.diamate.backend.api.dto.response.AuthResponse;
import com.diamate.backend.api.dto.response.UserResponse;
import com.diamate.backend.entity.Role;
import com.diamate.backend.exception.EmailAlreadyRegisteredException;
import com.diamate.backend.exception.InvalidCredentialsException;
import com.diamate.backend.exception.RegistrationNotAllowedException;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.AuthService;

/**
 * Web layer tests: real controllers, validation, GlobalExceptionHandler and SecurityConfig,
 * but AuthService is a mock, so no database is needed.
 */
@WebMvcTest(
        controllers = { AuthController.class, HealthController.class },
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class })
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AuthService authService;

    @Test
    void registerReturns201WithUserAndNoPasswordFields() throws Exception {
        when(authService.register(any())).thenReturn(
                new UserResponse(42L, "Melih", "Test", "melih.test@diamate.test", Role.CAREGIVER));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"Melih","lastName":"Test","email":"melih.test@diamate.test","password":"Secret123",
                                 "role":"CAREGIVER","dateOfBirth":"2000-01-15","gender":"MALE"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(42))
                .andExpect(jsonPath("$.firstName").value("Melih"))
                .andExpect(jsonPath("$.lastName").value("Test"))
                .andExpect(jsonPath("$.email").value("melih.test@diamate.test"))
                .andExpect(jsonPath("$.role").value("CAREGIVER"))
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.passwordHash").doesNotExist());
    }

    @Test
    void registerWithInvalidFieldsReturns400WithFieldErrorsAndSkipsTheService() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"","lastName":"","email":"not-an-email","password":"123","role":"PATIENT"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.title").value("Validation failed"))
                .andExpect(jsonPath("$.errors.firstName").value("First name is required"))
                .andExpect(jsonPath("$.errors.lastName").value("Last name is required"))
                .andExpect(jsonPath("$.errors.dateOfBirth").value("Date of birth is required"))
                .andExpect(jsonPath("$.errors.gender").value("Gender is required"))
                .andExpect(jsonPath("$.errors.email").value("Email format is invalid"))
                .andExpect(jsonPath("$.errors.password").value("Password must be at least 8 characters"));

        verifyNoInteractions(authService);
    }

    @Test
    void registerWithUnknownRoleReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"X","lastName":"Y","email":"x@example.com","password":"Secret123","role":"DOCTOR",
                                 "dateOfBirth":"2000-01-15","gender":"MALE"}
                                """))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(authService);
    }

    @Test
    void registerWithFutureBirthDateReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"X","lastName":"Y","email":"x@example.com","password":"Secret123",
                                 "role":"PATIENT","dateOfBirth":"2999-01-01","gender":"OTHER"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.dateOfBirth").value("Date of birth must be in the past"));

        verifyNoInteractions(authService);
    }

    @Test
    void registerWithUnknownGenderReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"X","lastName":"Y","email":"x@example.com","password":"Secret123",
                                 "role":"PATIENT","dateOfBirth":"2000-01-15","gender":"UNKNOWN"}
                                """))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(authService);
    }

    @Test
    void registerUnder16Returns400WithMessage() throws Exception {
        when(authService.register(any())).thenThrow(
                new RegistrationNotAllowedException("You must be at least 16 years old to register"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"Young","lastName":"User","email":"young@example.com","password":"Secret123",
                                 "role":"PATIENT","dateOfBirth":"2015-06-01","gender":"FEMALE"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("You must be at least 16 years old to register"));
    }

    @Test
    void registerWithTakenEmailReturns409() throws Exception {
        when(authService.register(any())).thenThrow(new EmailAlreadyRegisteredException());

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"X","lastName":"Y","email":"taken@example.com","password":"Secret123","role":"PATIENT",
                                 "dateOfBirth":"2000-01-15","gender":"FEMALE"}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.detail").value("Email is already registered"));
    }

    @Test
    void loginReturns200WithBearerToken() throws Exception {
        when(authService.login(any())).thenReturn(new AuthResponse("test-token", "Bearer", 3600,
                new UserResponse(5L, "Demo Patient", "01", "patient01@diamate.example", Role.PATIENT)));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"patient01@diamate.example","password":"whatever"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("test-token"))
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").value(3600))
                .andExpect(jsonPath("$.user.role").value("PATIENT"));
    }

    @Test
    void loginWithBadCredentialsReturns401ProblemDetail() throws Exception {
        when(authService.login(any())).thenThrow(new InvalidCredentialsException());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"patient01@diamate.example","password":"WrongPass1"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Invalid email or password"))
                .andExpect(jsonPath("$.errors").doesNotExist());
    }

    @Test
    void healthIsPublic() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void otherEndpointsRequireAToken() throws Exception {
        mockMvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized());
    }
}

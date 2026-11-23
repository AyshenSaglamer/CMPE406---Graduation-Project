package com.diamate.backend.api.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Duration;

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
import com.diamate.backend.exception.AccountLockedException;
import com.diamate.backend.exception.EmailAlreadyRegisteredException;
import com.diamate.backend.exception.InvalidCredentialsException;
import com.diamate.backend.exception.RegistrationNotAllowedException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
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
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AuthService authService;

    // Needed by the token check (ActiveAccountValidator); these tests send no tokens.
    @MockitoBean
    private UserRepository userRepository;

    @Test
    void registerReturns201WithUserAndNoPasswordFields() throws Exception {
        when(authService.register(any())).thenReturn(
                new UserResponse(42L, "Melih", "Test", Role.CAREGIVER, "melih.test@diamate.test"));

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
                new UserResponse(5L, "Demo Patient", "01", Role.PATIENT, "patient01@diamate.example")));

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
    void lockedAccountIs429WithRetryAfter() throws Exception {
        when(authService.login(any())).thenThrow(new AccountLockedException(Duration.ofMinutes(15)));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"patient01@diamate.example","password":"WrongPass1"}
                                """))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().string("Retry-After", "900"))
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Too many failed login attempts. Try again in 15 minutes."));
    }

    @Test
    void namesWithDigitsOrSymbolsAreRejected() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"R2D2","lastName":"<b>Test</b>","email":"x@example.com","password":"Kara-Deniz-42",
                                 "role":"PATIENT","dateOfBirth":"2000-01-15","gender":"OTHER"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.firstName")
                        .value("First name may only contain letters, spaces, apostrophes, hyphens and dots"))
                .andExpect(jsonPath("$.errors.lastName")
                        .value("Last name may only contain letters, spaces, apostrophes, hyphens and dots"));

        verifyNoInteractions(authService);
    }

    @Test
    void namesInAnyLanguageWithApostrophesHyphensAndDotsAreAccepted() throws Exception {
        when(authService.register(any())).thenReturn(
                new UserResponse(43L, "Ayşe Nur", "O’Brien-Yılmaz", Role.PATIENT, "ayse@example.com"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"Ayşe Nur","lastName":"O’Brien-Yılmaz","email":"ayse@example.com",
                                 "password":"Kara-Deniz-42","role":"PATIENT","dateOfBirth":"2000-01-15","gender":"FEMALE"}
                                """))
                .andExpect(status().isCreated());
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"J. R.","lastName":"D'Angelo","email":"jr@example.com",
                                 "password":"Kara-Deniz-42","role":"PATIENT","dateOfBirth":"2000-01-15","gender":"MALE"}
                                """))
                .andExpect(status().isCreated());
    }

    @Test
    void invalidDateIs400WithTheExpectedFormat() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"X","lastName":"Y","email":"x@example.com","password":"Kara-Deniz-42",
                                 "role":"PATIENT","dateOfBirth":"2000-13-45","gender":"OTHER"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.dateOfBirth").value("Must be a date in yyyy-MM-dd format"));

        verifyNoInteractions(authService);
    }

    @Test
    void anOldTokenSentToLoginOrRegisterIsIgnored() throws Exception {
        // A mobile app may still send its expired token on the login screen; that must not turn the login into a 401.
        when(authService.login(any())).thenReturn(new AuthResponse("new-token", "Bearer", 3600,
                new UserResponse(5L, "Demo Patient", "01", Role.PATIENT, "patient01@diamate.example")));
        when(authService.register(any())).thenReturn(
                new UserResponse(44L, "Melih", "Test", Role.PATIENT, "new@example.com"));

        mockMvc.perform(post("/api/v1/auth/login")
                        .header("Authorization", "Bearer old.expired.token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"patient01@diamate.example","password":"RightPass1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("new-token"));
        mockMvc.perform(post("/api/v1/auth/register")
                        .header("Authorization", "Bearer old.expired.token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName":"Melih","lastName":"Test","email":"new@example.com","password":"Kara-Deniz-42",
                                 "role":"PATIENT","dateOfBirth":"2000-01-15","gender":"MALE"}
                                """))
                .andExpect(status().isCreated());
    }

    @Test
    void wrongHttpMethodOnAPublicEndpointIs405Not401() throws Exception {
        mockMvc.perform(delete("/api/v1/auth/login"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON));
        verifyNoInteractions(authService);
    }

    @Test
    void controlCharactersInTextAreRejected() throws Exception {
        // The JSON escape for character code 0 (NUL): PostgreSQL cannot store it (it used to cause a 500 here).
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a\\u0000b@example.com\",\"password\":\"RightPass1\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.email").value("Must not contain control characters"));
        verifyNoInteractions(authService);
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

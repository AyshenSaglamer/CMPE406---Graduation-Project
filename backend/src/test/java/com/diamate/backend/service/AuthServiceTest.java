package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.request.LoginRequest;
import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.api.dto.response.AuthResponse;
import com.diamate.backend.api.dto.response.UserResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AccountDisabledException;
import com.diamate.backend.exception.EmailAlreadyRegisteredException;
import com.diamate.backend.exception.InvalidCredentialsException;
import com.diamate.backend.exception.RegistrationNotAllowedException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.JwtService;

/**
 * Unit tests: no Spring context and no database. The repository and JwtService are Mockito mocks;
 * the password encoder is a real BCrypt encoder (cost 4 instead of 10, to keep the tests fast).
 * "Today" is fixed to 2026-10-03 so the minimum-age rule can be tested exactly on the birthday boundary.
 */
@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final String PATIENT_EMAIL = "patient01@diamate.example";
    private static final String RIGHT_PASSWORD = "RightPass1";
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 3);
    private static final LocalDate ADULT_BIRTH_DATE = LocalDate.of(2000, 1, 15);

    @Mock
    private UserRepository userRepository;

    @Mock
    private JwtService jwtService;

    private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder(4);

    private AuthService authService;

    @BeforeEach
    void setUp() {
        Clock fixedClock = Clock.fixed(TODAY.atStartOfDay(ZoneId.of("UTC")).toInstant(), ZoneId.of("UTC"));
        authService = new AuthService(userRepository, passwordEncoder, jwtService, fixedClock);
    }

    // ---------- register ----------

    @Test
    void registerSavesNormalizedUserWithHashedPassword() {
        when(userRepository.existsByEmail("melih@example.com")).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class))).thenAnswer(invocation -> withId(invocation.getArgument(0), 42L));

        UserResponse response = authService.register(
                register("  Melih ", " Kocabıyık ", "  Melih@Example.COM ", Role.PATIENT, ADULT_BIRTH_DATE));

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(userRepository).saveAndFlush(saved.capture());
        assertThat(saved.getValue().getEmail()).isEqualTo("melih@example.com");
        assertThat(saved.getValue().getFirstName()).isEqualTo("Melih");
        assertThat(saved.getValue().getLastName()).isEqualTo("Kocabıyık");
        assertThat(saved.getValue().getDateOfBirth()).isEqualTo(ADULT_BIRTH_DATE);
        assertThat(saved.getValue().getGender()).isEqualTo(Gender.MALE);
        assertThat(saved.getValue().getPasswordHash()).startsWith("$2a$").isNotEqualTo("Secret123");
        assertThat(passwordEncoder.matches("Secret123", saved.getValue().getPasswordHash())).isTrue();
        assertThat(saved.getValue().isActive()).isTrue();
        assertThat(response).isEqualTo(new UserResponse(42L, "Melih", "Kocabıyık", "melih@example.com", Role.PATIENT));
    }

    @Test
    void registerAcceptsSomeoneTurning16Today() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class))).thenAnswer(invocation -> withId(invocation.getArgument(0), 43L));

        UserResponse response = authService.register(
                register("Deniz", "Yılmaz", "deniz@example.com", Role.PATIENT, TODAY.minusYears(16)));

        assertThat(response.id()).isEqualTo(43L);
    }

    @Test
    void registerRejectsSomeoneTurning16TomorrowWithoutTouchingTheDatabase() {
        assertThatThrownBy(() -> authService.register(
                register("Deniz", "Yılmaz", "deniz@example.com", Role.PATIENT, TODAY.minusYears(16).plusDays(1))))
                .isInstanceOf(RegistrationNotAllowedException.class)
                .hasMessage("You must be at least 16 years old to register");

        verifyNoInteractions(userRepository);
    }

    @Test
    void minimumAgeAppliesToEveryRole() {
        LocalDate fifteenYearsOld = TODAY.minusYears(15);
        for (Role role : new Role[] { Role.PATIENT, Role.CAREGIVER, Role.CLINICIAN }) {
            assertThatThrownBy(() -> authService.register(
                    register("Young", "User", "young@example.com", role, fifteenYearsOld)))
                    .isInstanceOf(RegistrationNotAllowedException.class);
        }
        verifyNoInteractions(userRepository);
    }

    @Test
    void registerRejectsAdminWithoutTouchingTheDatabase() {
        assertThatThrownBy(() -> authService.register(
                register("X", "Y", "x@example.com", Role.ADMIN, ADULT_BIRTH_DATE)))
                .isInstanceOf(RegistrationNotAllowedException.class);

        verifyNoInteractions(userRepository);
    }

    @Test
    void registerRejectsAlreadyRegisteredEmailIgnoringCase() {
        when(userRepository.existsByEmail("taken@example.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(
                register("X", "Y", "TAKEN@example.com", Role.CAREGIVER, ADULT_BIRTH_DATE)))
                .isInstanceOf(EmailAlreadyRegisteredException.class);

        verify(userRepository, never()).saveAndFlush(any());
    }

    @Test
    void registerTurnsUniqueIndexViolationIntoEmailAlreadyRegistered() {
        // Two simultaneous registrations: both pass existsByEmail, the database rejects the second insert.
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class)))
                .thenThrow(new DataIntegrityViolationException("duplicate key value violates unique constraint"));

        assertThatThrownBy(() -> authService.register(
                register("X", "Y", "race@example.com", Role.CLINICIAN, ADULT_BIRTH_DATE)))
                .isInstanceOf(EmailAlreadyRegisteredException.class);
    }

    // ---------- login ----------

    @Test
    void loginReturnsTokenAndRecordsLastLogin() {
        User patient = patient(true);
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(patient));
        when(jwtService.generateToken(patient)).thenReturn("test-token");
        when(jwtService.getExpirationSeconds()).thenReturn(3600L);

        AuthResponse response = authService.login(new LoginRequest(" PATIENT01@DIAMATE.EXAMPLE ", RIGHT_PASSWORD));

        assertThat(response.accessToken()).isEqualTo("test-token");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.expiresIn()).isEqualTo(3600L);
        assertThat(response.user()).isEqualTo(new UserResponse(5L, "Demo Patient", "01", PATIENT_EMAIL, Role.PATIENT));
        assertThat(patient.getLastLoginAt()).isNotNull();
    }

    @Test
    void loginWithUnknownEmailFailsWithGenericMessage() {
        when(userRepository.findByEmail("nobody@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(new LoginRequest("nobody@example.com", RIGHT_PASSWORD)))
                .isInstanceOf(InvalidCredentialsException.class)
                .hasMessage("Invalid email or password");
        verifyNoInteractions(jwtService);
    }

    @Test
    void loginWithWrongPasswordFailsWithTheSameGenericMessage() {
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(patient(true)));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PATIENT_EMAIL, "WrongPass1")))
                .isInstanceOf(InvalidCredentialsException.class)
                .hasMessage("Invalid email or password");
        verifyNoInteractions(jwtService);
    }

    @Test
    void loginDoesNotRevealDisabledAccountWithoutTheRightPassword() {
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(patient(false)));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PATIENT_EMAIL, "WrongPass1")))
                .isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    void loginRejectsDisabledAccountWithTheRightPassword() {
        User disabled = patient(false);
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(disabled));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PATIENT_EMAIL, RIGHT_PASSWORD)))
                .isInstanceOf(AccountDisabledException.class);
        assertThat(disabled.getLastLoginAt()).isNull();
        verifyNoInteractions(jwtService);
    }

    // ---------- helpers ----------

    private static RegisterRequest register(String firstName, String lastName, String email, Role role,
            LocalDate dateOfBirth) {
        return new RegisterRequest(firstName, lastName, email, "Secret123", role, dateOfBirth, Gender.MALE);
    }

    private User patient(boolean active) {
        User user = new User(PATIENT_EMAIL, passwordEncoder.encode(RIGHT_PASSWORD), Role.PATIENT,
                "Demo Patient", "01", LocalDate.of(1992, 7, 1), Gender.MALE);
        withId(user, 5L);
        ReflectionTestUtils.setField(user, "active", active);
        return user;
    }

    // In production the id comes from the database; here we set it the same way Hibernate would.
    private static User withId(User user, Long id) {
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }
}

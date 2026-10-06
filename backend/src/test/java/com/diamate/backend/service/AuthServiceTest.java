package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.sql.SQLException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
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
import com.diamate.backend.entity.DiabetesType;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.PatientProfile;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AccountDisabledException;
import com.diamate.backend.exception.AccountLockedException;
import com.diamate.backend.exception.EmailAlreadyRegisteredException;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.InvalidCredentialsException;
import com.diamate.backend.exception.RegistrationNotAllowedException;
import com.diamate.backend.repository.PatientProfileRepository;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.PasswordPolicy;
import com.diamate.backend.service.AuditService.LoginFailure;

/**
 * Unit tests: no Spring context and no database. The repository and JwtService are Mockito mocks;
 * the password encoder is a real BCrypt encoder (cost 4 instead of 10, to keep the tests fast).
 * "Today" is fixed to 2026-10-03 so the minimum-age rule can be tested exactly on the birthday boundary.
 * PasswordPolicy is the real one; the audit service is a mock (what it writes is tested in AuditServiceTest).
 */
@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final String PATIENT_EMAIL = "patient01@diamate.example";
    private static final String RIGHT_PASSWORD = "RightPass1";
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 3);
    private static final LocalDate ADULT_BIRTH_DATE = LocalDate.of(2000, 1, 15);
    private static final Instant NOW = TODAY.atStartOfDay(ZoneId.of("UTC")).toInstant();

    @Mock
    private UserRepository userRepository;

    @Mock
    private PatientProfileRepository patientProfileRepository;

    @Mock
    private JwtService jwtService;

    @Mock
    private AuditService auditService;

    private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder(4);

    private AuthService authService;

    @BeforeEach
    void setUp() {
        Clock fixedClock = Clock.fixed(NOW, ZoneId.of("UTC"));
        authService = new AuthService(userRepository, patientProfileRepository, passwordEncoder, new PasswordPolicy(),
                jwtService, auditService, fixedClock);
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
    void registeringAPatientAlsoCreatesTheirPatientProfile() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class))).thenAnswer(invocation -> withId(invocation.getArgument(0), 42L));

        authService.register(register("Ayşe", "Yılmaz", "ayse@example.com", Role.PATIENT, ADULT_BIRTH_DATE));

        // Without this row the patient could not save any glucose / insulin / meal / activity log.
        ArgumentCaptor<PatientProfile> profile = ArgumentCaptor.forClass(PatientProfile.class);
        verify(patientProfileRepository).save(profile.capture());
        assertThat(profile.getValue().getUserId()).isEqualTo(42L);
        assertThat(profile.getValue().getDiabetesType()).isEqualTo(DiabetesType.OTHER);
    }

    @Test
    void registeringOtherRolesCreatesNoPatientProfile() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class))).thenAnswer(invocation -> withId(invocation.getArgument(0), 43L));

        authService.register(register("Dr", "Test", "dr@example.com", Role.CLINICIAN, ADULT_BIRTH_DATE));
        authService.register(register("Care", "Giver", "care@example.com", Role.CAREGIVER, ADULT_BIRTH_DATE));

        verifyNoInteractions(patientProfileRepository);
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
        when(userRepository.saveAndFlush(any(User.class))).thenThrow(new DataIntegrityViolationException("duplicate key", new SQLException("duplicate key value violates unique constraint", "23505")));

        assertThatThrownBy(() -> authService.register(
                register("X", "Y", "race@example.com", Role.CLINICIAN, ADULT_BIRTH_DATE)))
                .isInstanceOf(EmailAlreadyRegisteredException.class);
        verifyNoInteractions(patientProfileRepository);
    }

    @Test
    void otherDatabaseErrorsAreNotReportedAsATakenEmail() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class))).thenThrow(new DataIntegrityViolationException("check violation", new SQLException("new row violates check constraint", "23514")));

        assertThatThrownBy(() -> authService.register(
                register("X", "Y", "x@example.com", Role.CLINICIAN, ADULT_BIRTH_DATE)))
                .isInstanceOf(DataIntegrityViolationException.class); // a bug: 500 + server log, not a misleading 409
    }

    @Test
    void birthDateMoreThan120YearsAgoIsATypingMistake() {
        assertThatThrownBy(() -> authService.register(
                register("Old", "Timer", "old@example.com", Role.PATIENT, LocalDate.of(1850, 1, 1))))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Date of birth must not be more than 120 years ago")
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("dateOfBirth"));
        verifyNoInteractions(userRepository);

        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.saveAndFlush(any(User.class))).thenAnswer(invocation -> withId(invocation.getArgument(0), 45L));
        assertThat(authService.register(
                register("Very", "Old", "old2@example.com", Role.PATIENT, TODAY.minusYears(120))).id()).isEqualTo(45L);
    }

    @Test
    void registerRejectsACommonPasswordOnThePasswordField() {
        assertThatThrownBy(() -> authService.register(new RegisterRequest("Ayşe", "Yılmaz", ADULT_BIRTH_DATE,
                Gender.FEMALE, "ayse@example.com", "Password123", Role.PATIENT)))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("This password is too common. Choose a less predictable one")
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("password"));

        verifyNoInteractions(userRepository);
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
        assertThat(patient.getLastLoginAt()).isEqualTo(NOW);
        verify(auditService).loginSucceeded(5L);
    }

    @Test
    void loginWithUnknownEmailFailsWithGenericMessage() {
        when(userRepository.findByEmail("nobody@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(new LoginRequest("nobody@example.com", RIGHT_PASSWORD)))
                .isInstanceOf(InvalidCredentialsException.class)
                .hasMessage("Invalid email or password");
        verifyNoInteractions(jwtService);
        verify(auditService).loginFailed(null, LoginFailure.UNKNOWN_EMAIL); // no account, so no user id
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
    void wrongPasswordIsCountedAndAudited() {
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(patient(true)));
        when(userRepository.findFailedLoginAttempts(5L)).thenReturn(3);

        assertThatThrownBy(() -> authService.login(new LoginRequest(PATIENT_EMAIL, "WrongPass1")))
                .isInstanceOf(InvalidCredentialsException.class);

        verify(userRepository).incrementFailedLoginAttempts(5L);
        verify(userRepository, never()).lockAccount(anyLong(), any());
        verify(auditService).loginFailed(5L, LoginFailure.WRONG_PASSWORD);
    }

    @Test
    void fifthWrongPasswordInARowLocksTheAccountFor15Minutes() {
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(patient(true)));
        when(userRepository.findFailedLoginAttempts(5L)).thenReturn(AuthService.MAX_FAILED_LOGIN_ATTEMPTS);

        assertThatThrownBy(() -> authService.login(new LoginRequest(PATIENT_EMAIL, "WrongPass1")))
                .isInstanceOf(AccountLockedException.class)
                .hasMessage("Too many failed login attempts. Try again in 15 minutes.");

        verify(userRepository).lockAccount(5L, NOW.plus(Duration.ofMinutes(15)));
        verify(auditService).accountLocked(5L, NOW.plus(Duration.ofMinutes(15)));
        verifyNoInteractions(jwtService);
    }

    @Test
    void lockedAccountIsRefusedEvenWithTheRightPassword() {
        User locked = patient(true);
        ReflectionTestUtils.setField(locked, "lockedUntil", NOW.plus(Duration.ofMinutes(10)));
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(locked));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PATIENT_EMAIL, RIGHT_PASSWORD)))
                .isInstanceOf(AccountLockedException.class)
                .hasMessage("Too many failed login attempts. Try again in 10 minutes.")
                .satisfies(e -> assertThat(((AccountLockedException) e).getRetryAfter()).isEqualTo(Duration.ofMinutes(10)));

        verify(userRepository, never()).incrementFailedLoginAttempts(anyLong()); // a refused attempt is not counted again
        verify(auditService).loginFailed(5L, LoginFailure.ACCOUNT_LOCKED);
        verifyNoInteractions(jwtService);
        assertThat(locked.getLastLoginAt()).isNull();
    }

    @Test
    void afterTheLockEndsTheRightPasswordWorksAndClearsTheCounter() {
        User wasLocked = patient(true);
        ReflectionTestUtils.setField(wasLocked, "lockedUntil", NOW.minusSeconds(1));
        ReflectionTestUtils.setField(wasLocked, "failedLoginAttempts", 2);
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(wasLocked));
        when(jwtService.generateToken(wasLocked)).thenReturn("test-token");

        authService.login(new LoginRequest(PATIENT_EMAIL, RIGHT_PASSWORD));

        assertThat(wasLocked.getFailedLoginAttempts()).isZero();
        assertThat(wasLocked.getLockedUntil()).isNull();
        assertThat(wasLocked.getLastLoginAt()).isEqualTo(NOW);
    }

    @Test
    void loginRejectsDisabledAccountWithTheRightPassword() {
        User disabled = patient(false);
        when(userRepository.findByEmail(PATIENT_EMAIL)).thenReturn(Optional.of(disabled));

        assertThatThrownBy(() -> authService.login(new LoginRequest(PATIENT_EMAIL, RIGHT_PASSWORD)))
                .isInstanceOf(AccountDisabledException.class);
        assertThat(disabled.getLastLoginAt()).isNull();
        verifyNoInteractions(jwtService);
        verify(auditService).loginFailed(5L, LoginFailure.ACCOUNT_DISABLED);
    }

    // ---------- helpers ----------

    private static RegisterRequest register(String firstName, String lastName, String email, Role role,
            LocalDate dateOfBirth) {
        return new RegisterRequest(firstName, lastName, dateOfBirth, Gender.MALE, email, "Secret123", role);
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

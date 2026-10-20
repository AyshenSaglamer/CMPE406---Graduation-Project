package com.diamate.backend.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.util.Locale;
import java.util.Optional;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.LoginRequest;
import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.api.dto.response.AuthResponse;
import com.diamate.backend.api.dto.response.UserResponse;
import com.diamate.backend.entity.ClinicianProfile;
import com.diamate.backend.entity.DiabetesType;
import com.diamate.backend.entity.PatientProfile;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AccountDisabledException;
import com.diamate.backend.exception.AccountLockedException;
import com.diamate.backend.exception.EmailAlreadyRegisteredException;
import com.diamate.backend.exception.InvalidCredentialsException;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.RegistrationNotAllowedException;
import com.diamate.backend.repository.ClinicianProfileRepository;
import com.diamate.backend.repository.PatientProfileRepository;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.PasswordPolicy;
import com.diamate.backend.service.AuditService.LoginFailure;

@Service
public class AuthService {

    private static final String TOKEN_TYPE = "Bearer";

    static final String CLINICIAN_NOT_APPROVED = "This doctor account is waiting for approval by an administrator";

    // Younger users not by self-registration.
    static final int MIN_SELF_REGISTRATION_AGE = 16;

    // A birth date further back than this is a typing mistake (e.g. 1850 instead of 1985).
    static final int MAX_AGE_YEARS = 120;

    // Brute-force protection: after this many wrong passwords in a row the account is locked for LOCK_DURATION.
    static final int MAX_FAILED_LOGIN_ATTEMPTS = 5;
    static final Duration LOCK_DURATION = Duration.ofMinutes(15);

    private final UserRepository userRepository;
    private final PatientProfileRepository patientProfileRepository;
    private final ClinicianProfileRepository clinicianProfileRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordPolicy passwordPolicy;
    private final JwtService jwtService;
    private final AuditService auditService;
    private final Clock clock;

    // Checked against when the email is unknown, so that a login for an unknown email
    // takes as long as one with a wrong password (no timing hint about which emails exist).
    private final String dummyPasswordHash;

    // Constructor
    public AuthService(UserRepository userRepository, PatientProfileRepository patientProfileRepository,
            ClinicianProfileRepository clinicianProfileRepository, PasswordEncoder passwordEncoder,
            PasswordPolicy passwordPolicy, JwtService jwtService, AuditService auditService, Clock clock) {
        this.userRepository = userRepository;
        this.patientProfileRepository = patientProfileRepository;
        this.clinicianProfileRepository = clinicianProfileRepository;
        this.passwordEncoder = passwordEncoder;
        this.passwordPolicy = passwordPolicy;
        this.jwtService = jwtService;
        this.auditService = auditService;
        this.clock = clock;
        this.dummyPasswordHash = passwordEncoder.encode("dummy-password-for-timing");
    }

    @Transactional // The entire method is a single operation. If an error occurs, the changes are rolled back.
    public UserResponse register(RegisterRequest request) {
        if (request.role() == Role.ADMIN) {
            throw new RegistrationNotAllowedException("ADMIN accounts cannot be self-registered");
        }
        if (ageOn(request.dateOfBirth(), LocalDate.now(clock)) < MIN_SELF_REGISTRATION_AGE) {
            throw new RegistrationNotAllowedException("You must be at least " + MIN_SELF_REGISTRATION_AGE + " years old to register");
        }
        if (request.dateOfBirth().isBefore(LocalDate.now(clock).minusYears(MAX_AGE_YEARS))) {
            throw new InvalidFieldException("dateOfBirth",
                    "Date of birth must not be more than " + MAX_AGE_YEARS + " years ago");
        }
        // 72-byte limit, common passwords, password = email (400 with an error on the "password" field)
        passwordPolicy.check(request.password(), request.email());

        String email = normalizeEmail(request.email());
        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyRegisteredException();
        }

        User user = new User(request.firstName().trim(), request.lastName().trim(), request.dateOfBirth(), request.gender(),
        		request.role(), email, passwordEncoder.encode(request.password()));
        // Anyone can choose CLINICIAN on the registration form, so a clinician starts inactive and an ADMIN approves
        // the account (PATCH /admin/users/{id}/status) before it can log in. Patients and caregivers start active.
        if (request.role() == Role.CLINICIAN) {
            user.changeActive(false);
        }
        User saved;
        try {
        	/**
        	 * It writes the user to the database and commits immediately. A standard save could have been deferred (postponed until the end of the transaction).
        	 * hits the unique index here and becomes a 409 instead of a 500.
        	 */
            saved = userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            // Only a duplicate email is a 409; any other database error is a bug and must not be reported as one.
            if (DatabaseErrors.isUniqueViolation(e)) {
                throw new EmailAlreadyRegisteredException();
            }
            throw e;
        }

        /**
         * Every patient log table points to patient_profiles, so a patient without this row could not save any data.
         * diabetes_type is required by the database but not asked at registration: OTHER until the patient sets it.
         * Same transaction as the user: if this fails, the user is not saved either.
         */
        if (saved.getRole() == Role.PATIENT) {
            patientProfileRepository.save(new PatientProfile(saved.getId(), DiabetesType.OTHER));
        }
        // Same for clinicians: treatment plans, prescriptions and recommendations point to clinician_profiles.
        if (saved.getRole() == Role.CLINICIAN) {
            clinicianProfileRepository.save(new ClinicianProfile(saved.getId()));
        }
        return UserResponse.from(saved);
    }

    /**
     * noRollbackFor: these exceptions are the normal answer to a bad login. What was written before them
     * (the failed-login counter, the lock, the audit rows) must be committed, not rolled back.
     */
    @Transactional(noRollbackFor = { InvalidCredentialsException.class, AccountLockedException.class,
            AccountDisabledException.class })
    public AuthResponse login(LoginRequest request) {
        Instant now = clock.instant();
        
        Optional<User> found = userRepository.findByEmail(normalizeEmail(request.email()));
        if (found.isEmpty()) {
            passwordEncoder.matches(request.password(), dummyPasswordHash);
            auditService.loginFailed(null, LoginFailure.UNKNOWN_EMAIL);
            throw new InvalidCredentialsException();
        }

        User user = found.get();
        // While locked, the password is not even checked: a correct guess during the lock must not get in.
        if (user.isLockedAt(now)) {
            auditService.loginFailed(user.getId(), LoginFailure.ACCOUNT_LOCKED);
            throw new AccountLockedException(Duration.between(now, user.getLockedUntil()));
        }
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            auditService.loginFailed(user.getId(), LoginFailure.WRONG_PASSWORD);
            userRepository.incrementFailedLoginAttempts(user.getId());
            if (userRepository.findFailedLoginAttempts(user.getId()) >= MAX_FAILED_LOGIN_ATTEMPTS) {
                Instant lockedUntil = now.plus(LOCK_DURATION);
                userRepository.lockAccount(user.getId(), lockedUntil);
                auditService.accountLocked(user.getId(), lockedUntil);
                throw new AccountLockedException(LOCK_DURATION);
            }
            throw new InvalidCredentialsException();
        }
        // Checked only after the password, so the account state is not revealed to someone without the password.
        if (!user.isActive()) {
            auditService.loginFailed(user.getId(), LoginFailure.ACCOUNT_DISABLED);
            // A clinician who has never logged in is (almost always) one who is still waiting for approval.
            throw user.getRole() == Role.CLINICIAN && user.getLastLoginAt() == null
                    ? new AccountDisabledException(CLINICIAN_NOT_APPROVED)
                    : new AccountDisabledException();
        }

        // The entity is managed inside the transaction: these changes are written with an UPDATE on commit.
        user.recordSuccessfulLogin(now);
        auditService.loginSucceeded(user.getId());

        String token = jwtService.generateToken(user);
        return new AuthResponse(token, TOKEN_TYPE, jwtService.getExpirationSeconds(), UserResponse.from(user));
    }

    /**
     * We don't simply calculate (current year - birth year) that would be incorrect.
     * Someone born in 2010 is still 15 in January 2026 (with a birthday in May).
     */
    private static int ageOn(LocalDate dateOfBirth, LocalDate today) {
        return Period.between(dateOfBirth, today).getYears();
    }
    
    /**
     * trim(): removes leading and trailing whitespace.
     * toLowerCase(Locale.ROOT): converts everything to lowercase.
     * Locale.ROOT: with a Turkish locale, "I".toLowerCase() would give a dotless "ı".
     */
    private static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
    
}
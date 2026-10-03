package com.diamate.backend.service;

import java.time.Clock;
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
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AccountDisabledException;
import com.diamate.backend.exception.EmailAlreadyRegisteredException;
import com.diamate.backend.exception.InvalidCredentialsException;
import com.diamate.backend.exception.RegistrationNotAllowedException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.JwtService;

@Service
public class AuthService {

    private static final String TOKEN_TYPE = "Bearer";

    // Younger users will be added later by a parent/guardian (family account), not by self-registration.
    static final int MIN_SELF_REGISTRATION_AGE = 16;

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final Clock clock;

    // Checked against when the email is unknown, so that a login for an unknown email
    // takes as long as one with a wrong password (no timing hint about which emails exist).
    private final String dummyPasswordHash;

    // Constructor
    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService,
            Clock clock) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.clock = clock;
        this.dummyPasswordHash = passwordEncoder.encode("dummy-password-for-timing");
    }

    @Transactional // The entire method is a single operation. If an error occurs, the changes are rolled back.
    public UserResponse register(RegisterRequest request) {
        if (request.role() == Role.ADMIN) {
            throw new RegistrationNotAllowedException("ADMIN accounts cannot be self-registered");
        }
        if (ageOn(request.dateOfBirth(), LocalDate.now(clock)) < MIN_SELF_REGISTRATION_AGE) {
            throw new RegistrationNotAllowedException(
                    "You must be at least " + MIN_SELF_REGISTRATION_AGE + " years old to register");
        }

        String email = normalizeEmail(request.email());
        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyRegisteredException();
        }

        User user = new User(email, passwordEncoder.encode(request.password()), request.role(),
                request.firstName().trim(), request.lastName().trim(), request.dateOfBirth(), request.gender());
        try {
            // Flush now so a duplicate that slipped past the check above (two requests at the same moment)
            // hits the unique index here and becomes a 409 instead of a 500.
            return UserResponse.from(userRepository.saveAndFlush(user));
        } catch (DataIntegrityViolationException e) {
            throw new EmailAlreadyRegisteredException();
        }
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        Optional<User> found = userRepository.findByEmail(normalizeEmail(request.email()));
        if (found.isEmpty()) {
            passwordEncoder.matches(request.password(), dummyPasswordHash);
            throw new InvalidCredentialsException();
        }

        User user = found.get();
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new InvalidCredentialsException();
        }
        // Checked only after the password, so the account state is not revealed to someone without the password.
        if (!user.isActive()) {
            throw new AccountDisabledException();
        }

        // The entity is managed inside the transaction: this change is written with an UPDATE on commit.
        user.setLastLoginAt(Instant.now());

        String token = jwtService.generateToken(user);
        return new AuthResponse(token, TOKEN_TYPE, jwtService.getExpirationSeconds(), UserResponse.from(user));
    }

    // Completed years: someone born on 2010-05-20 turns 16 on 2026-05-20, not a day earlier.
    private static int ageOn(LocalDate dateOfBirth, LocalDate today) {
        return Period.between(dateOfBirth, today).getYears();
    }

    // Locale.ROOT: with a Turkish locale, "I".toLowerCase() would give a dotless "ı".
    private static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
    
}
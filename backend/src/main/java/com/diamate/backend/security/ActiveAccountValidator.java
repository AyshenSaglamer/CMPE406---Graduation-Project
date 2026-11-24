package com.diamate.backend.security;

import java.time.Instant;
import java.util.UUID;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2ErrorCodes;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import com.diamate.backend.repository.UserRepository;

/**
 * A token is signed and has an expiry, but the account or the login can end before that.
 * This check runs on every request with a token (after signature, expiry and issuer are OK) and rejects it with
 * 401 at once if the user no longer exists, is no longer active, has another role than the one in the token
 * (the "role" claim decides what the token may do, so an old role must not keep working), or if the token's login
 * session ("sid" claim) was logged out, revoked or has expired. A token without a session is never accepted.
 */
@Component
public class ActiveAccountValidator implements OAuth2TokenValidator<Jwt> {

    private static final OAuth2TokenValidatorResult REJECTED = OAuth2TokenValidatorResult.failure(new OAuth2Error(
            OAuth2ErrorCodes.INVALID_TOKEN,
            "The session has ended, or the account is disabled, no longer exists or has another role", null));

    private final UserRepository userRepository;

    public ActiveAccountValidator(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        long userId;
        UUID sessionId;
        try {
            userId = Long.parseLong(token.getSubject()); // "sub" is the user id (JwtService)
            sessionId = UUID.fromString(token.getClaimAsString(JwtService.SESSION_CLAIM));
        } catch (IllegalArgumentException | NullPointerException e) { // NumberFormatException is an IllegalArgumentException
            return REJECTED;
        }
        String tokenRole = token.getClaimAsString(JwtService.ROLE_CLAIM);
        // The clock of the request; the token's own expiry was already checked by the standard validators.
        return userRepository.findRoleForOpenSession(userId, sessionId, Instant.now())
                .filter(role -> role.name().equals(tokenRole))
                .map(role -> OAuth2TokenValidatorResult.success())
                .orElse(REJECTED);
    }
}

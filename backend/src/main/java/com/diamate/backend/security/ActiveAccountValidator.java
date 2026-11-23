package com.diamate.backend.security;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2ErrorCodes;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import com.diamate.backend.repository.UserRepository;

/**
 * A token stays valid until it expires (up to 1 hour), even if the account changes in the meantime.
 * This check runs on every request with a token (after signature, expiry and issuer are OK) and rejects it with
 * 401 at once if the user no longer exists, is no longer active, or has another role than the one in the token
 * (the "role" claim decides what the token may do, so an old role must not keep working).
 */
@Component
public class ActiveAccountValidator implements OAuth2TokenValidator<Jwt> {

    private static final OAuth2TokenValidatorResult REJECTED = OAuth2TokenValidatorResult.failure(new OAuth2Error(
            OAuth2ErrorCodes.INVALID_TOKEN, "The account is disabled, no longer exists or has another role", null));

    private final UserRepository userRepository;

    public ActiveAccountValidator(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        long userId;
        try {
            userId = Long.parseLong(token.getSubject()); // "sub" is the user id (JwtService)
        } catch (NumberFormatException e) {
            return REJECTED;
        }
        String tokenRole = token.getClaimAsString(JwtService.ROLE_CLAIM);
        return userRepository.findActiveUserRole(userId)
                .filter(role -> role.name().equals(tokenRole))
                .map(role -> OAuth2TokenValidatorResult.success())
                .orElse(REJECTED);
    }
}

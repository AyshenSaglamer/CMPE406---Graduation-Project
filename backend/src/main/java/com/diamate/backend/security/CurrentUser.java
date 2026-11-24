package com.diamate.backend.security;

import java.util.UUID;

import org.springframework.security.oauth2.jwt.Jwt;

/** Reads the logged-in user's id from the validated token ("sub" claim, set by JwtService). */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static long id(Jwt jwt) {
        return Long.parseLong(jwt.getSubject());
    }

    /** The login session of the token ("sid" claim); ActiveAccountValidator has already checked that it is open. */
    public static UUID sessionId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString(JwtService.SESSION_CLAIM));
    }
}

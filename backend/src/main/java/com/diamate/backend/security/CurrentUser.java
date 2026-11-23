package com.diamate.backend.security;

import org.springframework.security.oauth2.jwt.Jwt;

/** Reads the logged-in user's id from the validated token ("sub" claim, set by JwtService). */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static long id(Jwt jwt) {
        return Long.parseLong(jwt.getSubject());
    }
}

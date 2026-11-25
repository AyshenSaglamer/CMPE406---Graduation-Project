package com.diamate.backend.api.dto.response;

/**
 * Returned by a successful login or refresh. The client sends the access token back as
 * "Authorization: Bearer <accessToken>". When it expires (or a request gets 401), the client calls
 * POST /api/v1/auth/refresh with the refresh token and replaces BOTH tokens with the answer: a refresh token works
 * only once.
 *
 * @param expiresIn        access token lifetime in seconds
 * @param refreshToken     keep it in secure storage on the device; it is not a JWT and only the backend can read it
 * @param refreshExpiresIn refresh token lifetime in seconds (starts again with every refresh)
 */
public record AuthResponse(String accessToken, String tokenType, long expiresIn, String refreshToken,
        long refreshExpiresIn, UserResponse user) {

}

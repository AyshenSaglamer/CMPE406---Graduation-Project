package com.diamate.backend.dto;

/**
 * Returned by a successful login. The client sends the token back as "Authorization: Bearer <accessToken>".
 *
 * @param expiresIn token lifetime in seconds
 */
public record AuthResponse(String accessToken, String tokenType, long expiresIn, UserResponse user) {
}

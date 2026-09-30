package com.diamate.backend.security;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Binds the diamate.jwt.* settings from application.yml.
 *
 * @param secret     base64-encoded HMAC key (at least 32 bytes once decoded)
 * @param expiration access token lifetime
 * @param issuer     value of the "iss" claim; tokens from any other issuer are rejected
 */
@Validated
@ConfigurationProperties(prefix = "diamate.jwt")
public record JwtProperties(
        @NotBlank String secret,
        @NotNull Duration expiration,
        @NotBlank String issuer) {
}

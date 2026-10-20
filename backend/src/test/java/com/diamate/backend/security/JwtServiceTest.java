package com.diamate.backend.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Base64;

import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

/**
 * What goes into an access token. The encoder is the application's own (SecurityConfig.jwtEncoder) and the clock is
 * fixed, so "iat" and "exp" can be checked to the second. Whether a token is accepted is tested in RbacWebTest.
 */
class JwtServiceTest {

    // base64 of "test-only-jwt-key-not-a-real-secret-0123456789" (same test key as the web tests)
    private static final String SECRET = "dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==";
    private static final Instant NOW = Instant.parse("2026-10-13T09:00:00Z");

    private final JwtProperties properties = new JwtProperties(SECRET, Duration.ofHours(1), "diamate-backend");
    private final JwtService jwtService = new JwtService(new SecurityConfig().jwtEncoder(properties), properties,
            Clock.fixed(NOW, ZoneOffset.UTC));

    @Test
    void tokenCarriesIssuerUserIdRoleAndALifetimeOfOneHour() {
        Jwt token = decode(jwtService.generateToken(patient()));

        assertThat(token.getHeaders()).containsEntry("alg", "HS256");
        assertThat(token.getClaimAsString("iss")).isEqualTo("diamate-backend");
        assertThat(token.getSubject()).isEqualTo("5");
        assertThat(token.getClaimAsString(JwtService.ROLE_CLAIM)).isEqualTo("PATIENT");
        assertThat(token.getIssuedAt()).isEqualTo(NOW);
        assertThat(token.getExpiresAt()).isEqualTo(NOW.plus(Duration.ofHours(1)));
        assertThat(jwtService.getExpirationSeconds()).isEqualTo(3600); // "expiresIn" of the login response
    }

    @Test
    void tokenHoldsNoPersonalData() {
        // The payload is only base64, anyone holding the token can read it.
        String token = jwtService.generateToken(patient());

        assertThat(decode(token).getClaims()).containsOnlyKeys("iss", "sub", "iat", "exp", JwtService.ROLE_CLAIM);
        String payload = new String(Base64.getUrlDecoder().decode(token.split("\\.")[1]), StandardCharsets.UTF_8);
        assertThat(payload).doesNotContain("ayse", "Ayşe", "Yılmaz", "FEMALE");
    }

    @Test
    void everyRoleIsWrittenWithItsDatabaseName() {
        for (Role role : Role.values()) {
            User user = new User("A", "B", LocalDate.of(1990, 5, 1), Gender.OTHER, role, "x@example.com", "hash");
            ReflectionTestUtils.setField(user, "id", 7L);

            assertThat(decode(jwtService.generateToken(user)).getClaimAsString(JwtService.ROLE_CLAIM))
                    .isEqualTo(role.name());
        }
    }

    /** Checks the signature with the same key; the expiry check is left out because the clock is fixed. */
    private static Jwt decode(String token) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder
                .withSecretKey(new SecretKeySpec(Base64.getDecoder().decode(SECRET), "HmacSHA256"))
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        decoder.setJwtValidator(jwt -> OAuth2TokenValidatorResult.success());
        return decoder.decode(token);
    }

    private static User patient() {
        User user = new User("Ayşe", "Yılmaz", LocalDate.of(1990, 5, 1), Gender.FEMALE, Role.PATIENT,
                "ayse@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", 5L);
        return user;
    }
}

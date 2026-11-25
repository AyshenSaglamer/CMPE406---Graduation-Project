package com.diamate.backend.security;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import com.diamate.backend.entity.User;

// Issues access tokens. Validation is done by Spring Security's resource server (see SecurityConfig).
@Service
public class JwtService {

    // Name of the token claim that carries the user's role (read back in SecurityConfig).
    public static final String ROLE_CLAIM = "role";

    // Name of the claim that carries the login session (auth_sessions.id). A token is accepted only while its session
    // is open (ActiveAccountValidator), so a logout ends it at once instead of when it expires.
    public static final String SESSION_CLAIM = "sid";

    private final JwtEncoder jwtEncoder;
    private final JwtProperties properties;
    private final Clock clock; // TimeConfig; a fixed clock in tests, so "iat" and "exp" can be checked exactly

    public JwtService(JwtEncoder jwtEncoder, JwtProperties properties, Clock clock) {
        this.jwtEncoder = jwtEncoder;
        this.properties = properties;
        this.clock = clock;
    }

    public String generateToken(User user, UUID sessionId) {
        Instant now = clock.instant();
        // The token payload is only base64-encoded, not encrypted: keep it to the id and role, no personal data.
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(properties.issuer())
                .subject(user.getId().toString())
                .issuedAt(now)
                .expiresAt(now.plus(properties.expiration()))
                .claim(ROLE_CLAIM, user.getRole().name())
                .claim(SESSION_CLAIM, sessionId.toString())
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }

    public long getExpirationSeconds() {
        return properties.expiration().toSeconds();
    }

    public long getRefreshExpirationSeconds() {
        return properties.refreshExpiration().toSeconds();
    }

}

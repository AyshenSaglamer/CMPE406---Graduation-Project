package com.diamate.backend.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.entity.AuthSession;
import com.diamate.backend.entity.AuthSession.RevokeReason;
import com.diamate.backend.repository.AuthSessionRepository;
import com.diamate.backend.security.JwtProperties;

/**
 * Login sessions (auth_sessions, V11) and their refresh tokens. A refresh token is 32 random bytes (base64url, 43
 * characters); only its SHA-256 is stored. Every refresh replaces it (rotation), and a replaced token that comes back
 * closes the session, because only a copy of it can still be in use.
 *
 * Runs inside AuthService's transactions (MANDATORY): the session and the login's other changes commit together.
 */
@Service
@Transactional(propagation = Propagation.MANDATORY)
public class AuthSessionService {

    /** A new or rotated session and the refresh token that only the app gets to see. */
    public record Issued(UUID sessionId, String refreshToken) {
    }

    /** What a refresh token turned out to be. */
    public sealed interface Lookup {
        record Open(AuthSession session) implements Lookup {
        }

        /** A token replaced by an earlier refresh: the session has just been closed (REUSED). */
        record Reused(AuthSession session) implements Lookup {
        }

        /** Unknown, expired or from a closed session. */
        record Invalid() implements Lookup {
        }
    }

    private static final int TOKEN_BYTES = 32;
    // Sessions that ended this long ago are deleted at the user's next login (nothing reads them any more).
    static final Duration KEEP_ENDED_SESSIONS = Duration.ofDays(30);

    private final AuthSessionRepository repository;
    private final JwtProperties properties;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public AuthSessionService(AuthSessionRepository repository, JwtProperties properties, Clock clock) {
        this.repository = repository;
        this.properties = properties;
        this.clock = clock;
    }

    public Issued open(long userId) {
        Instant now = clock.instant();
        repository.deleteEndedBefore(userId, now.minus(KEEP_ENDED_SESSIONS));
        String token = newToken();
        AuthSession session = new AuthSession(UUID.randomUUID(), userId, hash(token), now,
                now.plus(properties.refreshExpiration()));
        repository.save(session);
        return new Issued(session.getId(), token);
    }

    /** Locks the session row of the token, so two refreshes with one token cannot both succeed. */
    public Lookup find(String refreshToken) {
        Instant now = clock.instant();
        String hash = hash(refreshToken);
        Optional<AuthSession> current = repository.findByRefreshTokenHashForUpdate(hash);
        if (current.isPresent()) {
            return current.get().isOpenAt(now) ? new Lookup.Open(current.get()) : new Lookup.Invalid();
        }
        Optional<AuthSession> replaced = repository.findByPreviousTokenHashForUpdate(hash);
        if (replaced.isPresent() && replaced.get().isOpenAt(now)) {
            replaced.get().revoke(RevokeReason.REUSED, now);
            return new Lookup.Reused(replaced.get());
        }
        return new Lookup.Invalid();
    }

    /** A new refresh token for an open session; the lifetime starts again. */
    public Issued rotate(AuthSession session) {
        Instant now = clock.instant();
        String token = newToken();
        session.rotate(hash(token), now, now.plus(properties.refreshExpiration()));
        return new Issued(session.getId(), token);
    }

    public void revoke(AuthSession session, RevokeReason reason) {
        session.revoke(reason, clock.instant());
    }

    /** Logout of one session of the user. False if there is no such session or it was already closed. */
    public boolean logout(long userId, UUID sessionId) {
        Instant now = clock.instant();
        return repository.findByIdAndUserId(sessionId, userId)
                .filter(session -> session.isOpenAt(now))
                .map(session -> {
                    session.revoke(RevokeReason.LOGOUT, now);
                    return true;
                })
                .orElse(false);
    }

    private String newToken() {
        byte[] bytes = new byte[TOKEN_BYTES];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    static String hash(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is always available", e);
        }
    }
}

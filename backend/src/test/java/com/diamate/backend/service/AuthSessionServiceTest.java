package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.diamate.backend.entity.AuthSession;
import com.diamate.backend.entity.AuthSession.RevokeReason;
import com.diamate.backend.repository.AuthSessionRepository;
import com.diamate.backend.security.JwtProperties;

/** Refresh tokens: only the hash is stored, rotation keeps the previous hash, reuse closes the session. */
@ExtendWith(MockitoExtension.class)
class AuthSessionServiceTest {

    private static final Instant NOW = Instant.parse("2026-11-24T10:00:00Z");
    private static final Duration REFRESH_LIFETIME = Duration.ofDays(30);

    @Mock
    private AuthSessionRepository repository;

    private AuthSessionService service;

    @BeforeEach
    void setUp() {
        JwtProperties properties = new JwtProperties("unused", Duration.ofMinutes(15), REFRESH_LIFETIME, "diamate");
        service = new AuthSessionService(repository, properties, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void openStoresOnlyTheHashOfARandomToken() {
        AuthSessionService.Issued issued = service.open(5L);

        ArgumentCaptor<AuthSession> saved = ArgumentCaptor.forClass(AuthSession.class);
        verify(repository).save(saved.capture());
        assertThat(issued.refreshToken()).matches("[A-Za-z0-9_-]{43}"); // 32 random bytes, base64url
        assertThat(saved.getValue().getRefreshTokenHash())
                .isEqualTo(AuthSessionService.hash(issued.refreshToken()))
                .hasSize(64)
                .doesNotContain(issued.refreshToken());
        assertThat(saved.getValue().getId()).isEqualTo(issued.sessionId());
        assertThat(saved.getValue().getUserId()).isEqualTo(5L);
        assertThat(saved.getValue().getExpiresAt()).isEqualTo(NOW.plus(REFRESH_LIFETIME));
        // Old ended sessions of the user are cleaned up on the way.
        verify(repository).deleteEndedBefore(5L, NOW.minus(AuthSessionService.KEEP_ENDED_SESSIONS));
    }

    @Test
    void twoLoginsGetDifferentTokens() {
        assertThat(service.open(5L).refreshToken()).isNotEqualTo(service.open(5L).refreshToken());
    }

    @Test
    void rotateReplacesTheTokenKeepsThePreviousHashAndExtendsTheLifetime() {
        AuthSession session = session(NOW.plus(Duration.ofDays(2)));

        AuthSessionService.Issued issued = service.rotate(session);

        assertThat(issued.sessionId()).isEqualTo(session.getId());
        assertThat(session.getPreviousTokenHash()).isEqualTo(AuthSessionService.hash("refresh-1"));
        assertThat(session.getRefreshTokenHash()).isEqualTo(AuthSessionService.hash(issued.refreshToken()));
        assertThat(session.getExpiresAt()).isEqualTo(NOW.plus(REFRESH_LIFETIME));
    }

    @Test
    void currentTokenOfAnOpenSessionIsFound() {
        AuthSession session = session(NOW.plus(Duration.ofDays(1)));
        when(repository.findByRefreshTokenHashForUpdate(AuthSessionService.hash("refresh-1")))
                .thenReturn(Optional.of(session));

        assertThat(service.find("refresh-1")).isEqualTo(new AuthSessionService.Lookup.Open(session));
    }

    @Test
    void currentTokenOfAnExpiredOrLoggedOutSessionIsInvalid() {
        AuthSession expired = session(NOW);
        AuthSession loggedOut = session(NOW.plus(Duration.ofDays(1)));
        loggedOut.revoke(RevokeReason.LOGOUT, NOW.minusSeconds(5));
        when(repository.findByRefreshTokenHashForUpdate(anyString()))
                .thenReturn(Optional.of(expired)).thenReturn(Optional.of(loggedOut));

        assertThat(service.find("refresh-1")).isInstanceOf(AuthSessionService.Lookup.Invalid.class);
        assertThat(service.find("refresh-1")).isInstanceOf(AuthSessionService.Lookup.Invalid.class);
    }

    @Test
    void aReplacedTokenClosesItsSession() {
        AuthSession session = session(NOW.plus(Duration.ofDays(1)));
        session.rotate("new-hash", NOW.minusSeconds(60), NOW.plus(REFRESH_LIFETIME));
        when(repository.findByRefreshTokenHashForUpdate(anyString())).thenReturn(Optional.empty());
        when(repository.findByPreviousTokenHashForUpdate(AuthSessionService.hash("refresh-1")))
                .thenReturn(Optional.of(session));

        assertThat(service.find("refresh-1")).isEqualTo(new AuthSessionService.Lookup.Reused(session));
        assertThat(session.getRevokeReason()).isEqualTo(RevokeReason.REUSED);
        assertThat(session.getRevokedAt()).isEqualTo(NOW);
    }

    @Test
    void anUnknownTokenIsInvalid() {
        when(repository.findByRefreshTokenHashForUpdate(anyString())).thenReturn(Optional.empty());
        when(repository.findByPreviousTokenHashForUpdate(anyString())).thenReturn(Optional.empty());

        assertThat(service.find("whatever")).isInstanceOf(AuthSessionService.Lookup.Invalid.class);
    }

    @Test
    void logoutClosesOnlyAnOpenSessionOfTheSameUser() {
        AuthSession session = session(NOW.plus(Duration.ofDays(1)));
        when(repository.findByIdAndUserId(session.getId(), 5L)).thenReturn(Optional.of(session));
        when(repository.findByIdAndUserId(session.getId(), 6L)).thenReturn(Optional.empty());

        assertThat(service.logout(6L, session.getId())).isFalse(); // someone else's session
        assertThat(session.getRevokedAt()).isNull();
        assertThat(service.logout(5L, session.getId())).isTrue();
        assertThat(session.getRevokeReason()).isEqualTo(RevokeReason.LOGOUT);
        assertThat(service.logout(5L, session.getId())).isFalse(); // already closed
        verify(repository, never()).save(any());
    }

    private static AuthSession session(Instant expiresAt) {
        return new AuthSession(UUID.randomUUID(), 5L, AuthSessionService.hash("refresh-1"), NOW.minus(Duration.ofDays(3)),
                expiresAt);
    }
}

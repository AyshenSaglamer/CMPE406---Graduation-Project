package com.diamate.backend.entity;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * One login on one device (V11). The access token carries the id as its "sid" claim and is accepted only while the
 * session is open; the refresh token (only its SHA-256 hash is kept) gets new access tokens until the session
 * expires or is revoked.
 */
@Entity
@Table(name = "auth_sessions")
public class AuthSession {

    public enum RevokeReason { LOGOUT, REUSED, ACCOUNT_DISABLED }

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private long userId;

    @Column(name = "refresh_token_hash", nullable = false, length = 64)
    private String refreshTokenHash;

    @Column(name = "previous_token_hash", length = 64)
    private String previousTokenHash;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "last_refreshed_at")
    private Instant lastRefreshedAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "revoke_reason", length = 20)
    private RevokeReason revokeReason;

    protected AuthSession() {
        // for JPA
    }

    public AuthSession(UUID id, long userId, String refreshTokenHash, Instant createdAt, Instant expiresAt) {
        this.id = id;
        this.userId = userId;
        this.refreshTokenHash = refreshTokenHash;
        this.createdAt = createdAt;
        this.expiresAt = expiresAt;
    }

    public boolean isOpenAt(Instant now) {
        return revokedAt == null && expiresAt.isAfter(now);
    }

    /** A new refresh token replaces the current one; the current one is kept to recognise a later reuse. */
    public void rotate(String newRefreshTokenHash, Instant now, Instant newExpiresAt) {
        this.previousTokenHash = this.refreshTokenHash;
        this.refreshTokenHash = newRefreshTokenHash;
        this.lastRefreshedAt = now;
        this.expiresAt = newExpiresAt;
    }

    public void revoke(RevokeReason reason, Instant now) {
        if (revokedAt == null) {
            this.revokedAt = now;
            this.revokeReason = reason;
        }
    }

    public UUID getId() {
        return id;
    }

    public long getUserId() {
        return userId;
    }

    public String getRefreshTokenHash() {
        return refreshTokenHash;
    }

    public String getPreviousTokenHash() {
        return previousTokenHash;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public Instant getRevokedAt() {
        return revokedAt;
    }

    public RevokeReason getRevokeReason() {
        return revokeReason;
    }
}

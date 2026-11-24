package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import com.diamate.backend.entity.AuthSession;

public interface AuthSessionRepository extends JpaRepository<AuthSession, UUID> {

    // Refresh: SELECT ... FOR UPDATE, so two refreshes with the same token wait for each other. The second one then
    // finds the token as previous_token_hash (reuse) instead of rotating the session a second time.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from AuthSession s where s.refreshTokenHash = :hash")
    Optional<AuthSession> findByRefreshTokenHashForUpdate(@Param("hash") String hash);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from AuthSession s where s.previousTokenHash = :hash")
    Optional<AuthSession> findByPreviousTokenHashForUpdate(@Param("hash") String hash);

    @Query("select s from AuthSession s where s.id = :id and s.userId = :userId")
    Optional<AuthSession> findByIdAndUserId(@Param("id") UUID id, @Param("userId") long userId);

    // Housekeeping at login: a user's sessions that ended (expired or revoked) before :before are no longer needed.
    @Modifying
    @Query("delete from AuthSession s where s.userId = :userId and (s.expiresAt < :before or s.revokedAt < :before)")
    int deleteEndedBefore(@Param("userId") long userId, @Param("before") Instant before);
}

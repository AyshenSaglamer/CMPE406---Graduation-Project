package com.diamate.backend.repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

public interface UserRepository extends JpaRepository<User, Long> {

    // lower(...) on both sides matches the unique index ux_users_email_lower,
    // so lookups are case-insensitive and use the index.
    @Query("select u from User u where lower(u.email) = lower(:email)")
    Optional<User> findByEmail(@Param("email") String email);

    // Login only: the same lookup with SELECT ... FOR UPDATE. Parallel logins to one account wait for each other
    // until the transaction ends, so each one sees the counter and the lock the previous one committed. Without it,
    // a burst of parallel guesses all read "not locked" and get past the limit of 5.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from User u where lower(u.email) = lower(:email)")
    Optional<User> findByEmailForLogin(@Param("email") String email);

    @Query("select count(u) > 0 from User u where lower(u.email) = lower(:email)")
    boolean existsByEmail(@Param("email") String email);

    // Derived query: Spring Data builds "select u from User u order by u.id asc" from the method name.
    List<User> findAllByOrderByIdAsc();

    // Checked on every request with a token (ActiveAccountValidator): the role of the user if the account exists and
    // is active and the token's login session is still open (not logged out, not expired), otherwise empty. One small
    // query instead of loading the whole user.
    @Query("""
            select u.role from User u, AuthSession s
            where u.id = :id and u.active = true
              and s.id = :sessionId and s.userId = u.id and s.revokedAt is null and s.expiresAt > :now""")
    Optional<Role> findRoleForOpenSession(@Param("id") long id, @Param("sessionId") UUID sessionId,
            @Param("now") Instant now);

    // Failed logins are counted in the database with "+ 1" instead of read-change-write in Java: parallel attempts
    // wait for each other's row lock, so none of them can overwrite another's count and slip past the limit.
    @Modifying
    @Query("update User u set u.failedLoginAttempts = u.failedLoginAttempts + 1 where u.id = :id")
    void incrementFailedLoginAttempts(@Param("id") long id);

    @Query("select u.failedLoginAttempts from User u where u.id = :id")
    int findFailedLoginAttempts(@Param("id") long id);

    // The counter starts again from 0, so after the lock ends the user has the full number of attempts again.
    @Modifying
    @Query("update User u set u.failedLoginAttempts = 0, u.lockedUntil = :until where u.id = :id")
    void lockAccount(@Param("id") long id, @Param("until") Instant until);
    
}
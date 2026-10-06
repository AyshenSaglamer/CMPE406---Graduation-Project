package com.diamate.backend.repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

public interface UserRepository extends JpaRepository<User, Long> {

    // lower(...) on both sides matches the unique index ux_users_email_lower,
    // so lookups are case-insensitive and use the index.
    @Query("select u from User u where lower(u.email) = lower(:email)")
    Optional<User> findByEmail(@Param("email") String email);

    @Query("select count(u) > 0 from User u where lower(u.email) = lower(:email)")
    boolean existsByEmail(@Param("email") String email);

    // Derived query: Spring Data builds "select u from User u order by u.id asc" from the method name.
    List<User> findAllByOrderByIdAsc();

    // Checked on every request with a token (ActiveAccountValidator): the role of the user if the account exists and
    // is active, otherwise empty. One small query instead of loading the whole user.
    @Query("select u.role from User u where u.id = :id and u.active = true")
    Optional<Role> findActiveUserRole(@Param("id") long id);

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
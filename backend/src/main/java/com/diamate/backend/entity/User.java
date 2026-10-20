package com.diamate.backend.entity;

import java.time.Instant;
import java.time.LocalDate;

import org.hibernate.annotations.DynamicUpdate;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Maps the users table (see Database/sql/06_app_schema.sql and db/migration).
 * Not mapped: the two-factor columns (nothing uses them yet) and full_name, which the database generates from first_name and last_name.
 *
 * @DynamicUpdate: an UPDATE writes only the changed columns. A login (last_login_at, failed-login counter) then
 * never writes back old values of other columns, e.g. an is_active = false set at the same moment.
 */
@Entity // This class represents a table
@Table(name = "users")
@DynamicUpdate
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY) // The database generates the ID.
    private Long id;

    @Column(name = "first_name", nullable = false, length = 50)
    private String firstName;

    @Column(name = "last_name", nullable = false, length = 50)
    private String lastName;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Gender gender;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;
    
    @Column(nullable = false, length = 150)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(length = 30)
    private String phone;

    @Column(name = "email_verified", nullable = false)
    private boolean emailVerified = false;

    @Column(name = "failed_login_attempts", nullable = false)
    private int failedLoginAttempts = 0;

    @Column(name = "locked_until")
    private Instant lockedUntil;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;
    
    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "is_demo", nullable = false)
    private boolean demo = false;

    // Filled by the database (DEFAULT now()); Hibernate reads the value back after insert.
    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    // Filled by the database (DEFAULT now() and the trg_users_updated trigger).
    @Generated(event = { EventType.INSERT, EventType.UPDATE })
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    
    protected User() {
        // required by JPA
    }

    public User(String firstName, String lastName, LocalDate dateOfBirth, Gender gender, Role role , String email, String passwordHash) {
    	this.firstName = firstName;
        this.lastName = lastName;
        this.dateOfBirth = dateOfBirth;
        this.gender = gender;
        this.role = role;
    	this.email = email;
        this.passwordHash = passwordHash;  
    }

    
    public Long getId() {
        return id;
    }
    
    public String getFirstName() {
        return firstName;
    }

    public String getLastName() {
        return lastName;
    }
    
    public LocalDate getDateOfBirth() {
        return dateOfBirth;
    }
    
    public Gender getGender() {
        return gender;
    }
    
    public Role getRole() {
        return role;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getPhone() {
        return phone;
    }
    
    public boolean isEmailVerified() {
        return emailVerified;
    }
    
    public int getFailedLoginAttempts() {
        return failedLoginAttempts;
    }

    public Instant getLockedUntil() {
        return lockedUntil;
    }

    public Instant getLastLoginAt() {
        return lastLoginAt;
    }

    public boolean isActive() {
        return active;
    }

    public boolean isDemo() {
        return demo;
    }
    
    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    // True while a lock caused by too many failed logins is still in force.
    public boolean isLockedAt(Instant now) {
        return lockedUntil != null && lockedUntil.isAfter(now);
    }

    // A successful login clears the failed-login counter and an expired lock.
    public void recordSuccessfulLogin(Instant now) {
        this.failedLoginAttempts = 0;
        this.lockedUntil = null;
        this.lastLoginAt = now;
    }

    // Activated / deactivated by an ADMIN (or inactive from the start: a clinician waits for approval).
    // An inactive account cannot log in, and its tokens get 401 at once (ActiveAccountValidator).
    public void changeActive(boolean active) {
        this.active = active;
    }
  
}
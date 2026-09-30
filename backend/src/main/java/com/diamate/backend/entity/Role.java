package com.diamate.backend.entity;

/**
 * User roles. Constant names must match the CHECK constraint on users.role exactly.
 */
public enum Role {
    PATIENT,
    CLINICIAN,
    CAREGIVER,
    ADMIN
}

package com.diamate.backend.entity;

// User roles. Constant names must match the CHECK constraint on users.role exactly.
public enum Role {
    PATIENT,
    CLINICIAN, // the app's "doctor"; the database, Flutter and @PreAuthorize rules all use CLINICIAN
    CAREGIVER,
    ADMIN
    
}
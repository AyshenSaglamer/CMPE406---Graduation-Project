package com.diamate.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Maps clinician_profiles: one row per CLINICIAN user (the report's DOCTOR table). Treatment plans, prescribed
 * medications and recommendations point here, so a clinician without this row could not be named in them.
 * Only the id is mapped: specialization ('General'), hospital and license number keep their database defaults until
 * a profile endpoint exists.
 */
@Entity
@Table(name = "clinician_profiles")
public class ClinicianProfile {

    // Same value as users.id (not generated): the profile shares the user's id.
    @Id
    @Column(name = "user_id")
    private Long userId;

    protected ClinicianProfile() {
        // required by JPA
    }

    public ClinicianProfile(long userId) {
        this.userId = userId;
    }

    public Long getUserId() {
        return userId;
    }
}

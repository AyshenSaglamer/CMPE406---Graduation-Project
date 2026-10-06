package com.diamate.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Maps patient_profiles: one row per PATIENT user. Every patient log table points here (patient_id), so a patient
 * without this row cannot save any data. Only the columns the backend writes today are mapped; the targets and alert
 * thresholds keep their database defaults (70/180, 54/250) until a profile endpoint exists.
 */
@Entity
@Table(name = "patient_profiles")
public class PatientProfile {

    // Same value as users.id (not generated): the profile shares the user's id.
    @Id
    @Column(name = "user_id")
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "diabetes_type", nullable = false, length = 20)
    private DiabetesType diabetesType;

    protected PatientProfile() {
        // required by JPA
    }

    public PatientProfile(long userId, DiabetesType diabetesType) {
        this.userId = userId;
        this.diabetesType = diabetesType;
    }

    public Long getUserId() {
        return userId;
    }

    public DiabetesType getDiabetesType() {
        return diabetesType;
    }
}

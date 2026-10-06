package com.diamate.backend.service;

import org.springframework.stereotype.Component;

import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.PatientAccessRepository;

/**
 * Who may read or write a patient's health logs. Kept in one place so every log type follows the same rule
 * (and so the write rule can be widened later, e.g. for caregivers, without touching four services).
 *
 * Both checks answer 404 "Patient not found" when access is missing, like the overview endpoint: the
 * response must not reveal whether a patient id exists.
 */
@Component
public class HealthDataAccess {

    private final PatientAccessRepository patientAccessRepository;

    public HealthDataAccess(PatientAccessRepository patientAccessRepository) {
        this.patientAccessRepository = patientAccessRepository;
    }

    /** The patient, or a clinician / caregiver with an ACTIVE relationship that grants this permission (fn_can_access). */
    public void checkCanRead(long viewerId, long patientId, String permission) {
        if (!patientAccessRepository.canAccess(viewerId, patientId, permission)) {
            throw new ResourceNotFoundException("Patient not found");
        }
    }

    /**
     * Current rule: only the patient writes their own logs. The controllers also require the PATIENT role
     * (@PreAuthorize), so clinicians and caregivers get 403 before reaching this check.
     */
    public void checkCanWrite(long viewerId, long patientId) {
        if (viewerId != patientId) {
            throw new ResourceNotFoundException("Patient not found");
        }
    }
}

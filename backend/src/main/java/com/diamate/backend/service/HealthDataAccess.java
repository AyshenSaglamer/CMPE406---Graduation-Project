package com.diamate.backend.service;

import org.springframework.stereotype.Component;

import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.PatientAccessRepository;

/**
 * Who may read or write a patient's health data. Kept in one place so every data type follows the same rule
 * (and so the write rule can be widened later, e.g. for caregivers, without touching every service).
 *
 * Both checks answer 404 "Patient not found" when access is missing, like the overview endpoint: the
 * response must not reveal whether a patient id exists.
 */
@Component
public class HealthDataAccess {

    private final PatientAccessRepository patientAccessRepository;
    private final AuditService auditService;

    public HealthDataAccess(PatientAccessRepository patientAccessRepository, AuditService auditService) {
        this.patientAccessRepository = patientAccessRepository;
        this.auditService = auditService;
    }

    /**
     * The patient, or a clinician / caregiver with an ACTIVE relationship that grants the permission of this data
     * type (fn_can_access). A read by anyone other than the patient is written to the audit log, allowed or not.
     *
     * The audit row is written in its own transaction, so callers must not be inside a read-only transaction:
     * the services' read methods are therefore not @Transactional (each repository call has its own).
     */
    public void checkCanRead(long viewerId, long patientId, PatientDataType data) {
        boolean allowed = patientAccessRepository.canAccess(viewerId, patientId, data.permission());
        if (viewerId != patientId) {
            auditService.patientDataViewed(viewerId, patientId, data, allowed);
        }
        if (!allowed) {
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

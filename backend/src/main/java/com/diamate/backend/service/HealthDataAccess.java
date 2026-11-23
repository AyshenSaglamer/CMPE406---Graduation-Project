package com.diamate.backend.service;

import java.util.Arrays;
import java.util.EnumSet;
import java.util.Set;

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
        if (!canRead(viewerId, patientId, data)) {
            throw new ResourceNotFoundException("Patient not found");
        }
    }

    /**
     * Same rule and audit row as checkCanRead, but answers instead of throwing: for a response that combines several
     * data types and simply leaves out the ones the viewer may not see (the AI patient summary).
     */
    public boolean canRead(long viewerId, long patientId, PatientDataType data) {
        boolean allowed = patientAccessRepository.canAccess(viewerId, patientId, data.permission());
        if (viewerId != patientId) {
            auditService.patientDataViewed(viewerId, patientId, data, allowed);
        }
        return allowed;
    }

    /**
     * Which of these data types the viewer may see, without an audit row. Only for deciding which FIELDS of a response
     * that was already checked and audited with checkCanRead are shown (the overview's therapy type and open-alert
     * count). Package-private on purpose: returning a data set must go through checkCanRead / canRead, so the read is
     * audited.
     */
    Set<PatientDataType> visibleFields(long viewerId, long patientId, PatientDataType... fields) {
        Set<String> granted = patientAccessRepository.grantedPermissions(viewerId, patientId,
                Arrays.stream(fields).map(PatientDataType::permission).toList());
        Set<PatientDataType> visible = EnumSet.noneOf(PatientDataType.class);
        for (PatientDataType field : fields) {
            if (granted.contains(field.permission())) {
                visible.add(field);
            }
        }
        return visible;
    }

    /**
     * Records that a log was corrected or deleted (who, whose, which log; not the values). Called by the log services
     * inside their transaction, so the audit row and the change are committed together.
     */
    public void recordChange(long viewerId, long patientId, PatientDataType data, long logId,
            AuditService.HealthLogChange change) {
        auditService.healthLogChanged(viewerId, patientId, data, logId, change);
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

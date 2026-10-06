package com.diamate.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.response.CareTeamPatientResponse;
import com.diamate.backend.api.dto.response.PatientOverviewResponse;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.PatientAccessRepository;

@Service
public class PatientService {

    private final PatientAccessRepository patientAccessRepository;
    private final HealthDataAccess access;

    public PatientService(PatientAccessRepository patientAccessRepository, HealthDataAccess access) {
        this.patientAccessRepository = patientAccessRepository;
        this.access = access;
    }

    /**
     * Object-level authorization: the role check alone is not enough, because any clinician could otherwise
     * read any patient by changing the id in the URL. "No access" and "no such patient" both return 404,
     * so the response does not reveal which patient ids exist.
     * Not @Transactional: the access check may write an audit row in its own transaction (see HealthDataAccess).
     */
    public PatientOverviewResponse getOverview(long viewerId, long patientId) {
        access.checkCanRead(viewerId, patientId, PatientDataType.OVERVIEW);
        return patientAccessRepository.findOverview(patientId)
                .map(PatientOverviewResponse::from)
                .orElseThrow(() -> new ResourceNotFoundException("Patient not found"));
    }

    /** Patients of a clinician or caregiver (role enforced in CareTeamController). */
    @Transactional(readOnly = true)
    public List<CareTeamPatientResponse> getCareTeamPatients(long memberId) {
        return patientAccessRepository.findActivePatientsOf(memberId).stream()
                .map(CareTeamPatientResponse::from)
                .toList();
    }
}

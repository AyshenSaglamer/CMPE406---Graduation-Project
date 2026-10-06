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

    public PatientService(PatientAccessRepository patientAccessRepository) {
        this.patientAccessRepository = patientAccessRepository;
    }

    /**
     * Object-level authorization: the role check alone is not enough, because any clinician could otherwise
     * read any patient by changing the id in the URL. "No access" and "no such patient" both return 404,
     * so the response does not reveal which patient ids exist.
     */
    @Transactional(readOnly = true)
    public PatientOverviewResponse getOverview(long viewerId, long patientId) {
        if (!patientAccessRepository.canAccess(viewerId, patientId, PatientAccessRepository.PERMISSION_GLUCOSE)) {
            throw new ResourceNotFoundException("Patient not found");
        }
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

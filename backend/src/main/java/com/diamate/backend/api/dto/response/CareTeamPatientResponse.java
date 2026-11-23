package com.diamate.backend.api.dto.response;

import com.diamate.backend.repository.PatientAccessRepository.CareTeamPatientRow;

// A patient on the caller's care list, with what the patient allowed this clinician/caregiver to see.
public record CareTeamPatientResponse(long patientId, String firstName, String lastName,
        boolean canViewGlucose, boolean canViewMeals, boolean canViewMedications, boolean canViewActivity,
        boolean canViewReports, boolean canReceiveAlerts, boolean canAddRecommendations) {

    public static CareTeamPatientResponse from(CareTeamPatientRow row) {
        return new CareTeamPatientResponse(row.patientId(), row.firstName(), row.lastName(),
                row.canViewGlucose(), row.canViewMeals(), row.canViewMedications(), row.canViewActivity(),
                row.canViewReports(), row.canReceiveAlerts(), row.canAddRecommendations());
    }
}

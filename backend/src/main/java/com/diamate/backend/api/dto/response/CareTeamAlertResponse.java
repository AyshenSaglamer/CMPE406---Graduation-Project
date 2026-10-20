package com.diamate.backend.api.dto.response;

import com.diamate.backend.entity.Alert;
import com.diamate.backend.repository.PatientAccessRepository.CareTeamPatientRow;

/** One alert in GET /care-team/alerts: whose it is (for the list) and the alert itself, as GET .../alerts returns it. */
public record CareTeamAlertResponse(long patientId, String patientFirstName, String patientLastName,
        AlertResponse alert) {

    public static CareTeamAlertResponse from(CareTeamPatientRow patient, Alert alert) {
        return new CareTeamAlertResponse(patient.patientId(), patient.firstName(), patient.lastName(),
                AlertResponse.from(alert));
    }
}

package com.diamate.backend.api.dto.response;

import java.time.Instant;

import com.diamate.backend.repository.PatientAccessRepository.PatientOverviewRow;

// Summary card of a patient (GET /api/v1/patients/{patientId}/overview). Glucose values in mg/dL.
// therapyType is null without the "medications" permission, openAlerts null without the "alerts" permission.
public record PatientOverviewResponse(long patientId, String firstName, String lastName, String gender,
        Integer ageYears, String diabetesType, String therapyType, int targetMinMgdl, int targetMaxMgdl,
        Integer lastGlucoseMgdl, Instant lastGlucoseAt, Long openAlerts) {

    public static PatientOverviewResponse from(PatientOverviewRow row) {
        return new PatientOverviewResponse(row.patientId(), row.firstName(), row.lastName(), row.gender(),
                row.ageYears(), row.diabetesType(), row.therapyType(), row.targetMinMgdl(), row.targetMaxMgdl(),
                row.lastGlucoseMgdl(), row.lastGlucoseAt(), row.openAlerts());
    }

    /** The same card without the fields the viewer has no permission for. */
    public PatientOverviewResponse limitedTo(boolean medications, boolean alerts) {
        return new PatientOverviewResponse(patientId, firstName, lastName, gender, ageYears, diabetesType,
                medications ? therapyType : null, targetMinMgdl, targetMaxMgdl, lastGlucoseMgdl, lastGlucoseAt,
                alerts ? openAlerts : null);
    }
}

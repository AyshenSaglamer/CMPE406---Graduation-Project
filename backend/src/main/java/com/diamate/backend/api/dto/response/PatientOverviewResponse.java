package com.diamate.backend.api.dto.response;

import java.time.Instant;

import com.diamate.backend.repository.PatientAccessRepository.PatientOverviewRow;

// Summary card of a patient (GET /api/v1/patients/{patientId}/overview). Glucose values in mg/dL.
public record PatientOverviewResponse(long patientId, String firstName, String lastName, String gender,
        Integer ageYears, String diabetesType, String therapyType, int targetMinMgdl, int targetMaxMgdl,
        Integer lastGlucoseMgdl, Instant lastGlucoseAt, long openAlerts) {

    public static PatientOverviewResponse from(PatientOverviewRow row) {
        return new PatientOverviewResponse(row.patientId(), row.firstName(), row.lastName(), row.gender(),
                row.ageYears(), row.diabetesType(), row.therapyType(), row.targetMinMgdl(), row.targetMaxMgdl(),
                row.lastGlucoseMgdl(), row.lastGlucoseAt(), row.openAlerts());
    }
}

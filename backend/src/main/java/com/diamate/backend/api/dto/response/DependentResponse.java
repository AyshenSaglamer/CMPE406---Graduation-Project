package com.diamate.backend.api.dto.response;

import java.time.LocalDate;

import com.diamate.backend.entity.DiabetesType;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.PatientProfile;
import com.diamate.backend.entity.User;

/**
 * A dependent the caller manages. patientId is the id to use for their logs (/patients/{patientId}/glucose-logs ...).
 * relationshipId is the managing care relationship.
 */
public record DependentResponse(long patientId, String firstName, String lastName, LocalDate dateOfBirth,
        Gender gender, DiabetesType diabetesType, long relationshipId) {

    public static DependentResponse from(User user, PatientProfile profile, long relationshipId) {
        return new DependentResponse(user.getId(), user.getFirstName(), user.getLastName(), user.getDateOfBirth(),
                user.getGender(), profile.getDiabetesType(), relationshipId);
    }
}

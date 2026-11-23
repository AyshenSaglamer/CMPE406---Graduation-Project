package com.diamate.backend.api.dto.response;

import java.time.Instant;

import com.diamate.backend.repository.CareRelationshipRepository.CareRelationshipRow;
import com.diamate.backend.repository.CareRelationshipRepository.Permissions;

/**
 * A care relationship as both sides see it. status: PENDING (invited, not answered yet), ACTIVE (data is shared),
 * DECLINED (the member said no) or REVOKED (ended by either side). The patient's email is not included: the member
 * does not need it. The member's email is, because the patient typed it to send the invitation.
 *
 * hasAccess says whether the member can see the patient's data right now: ACTIVE and not past expiresAt. An expired
 * relationship keeps the status ACTIVE (nobody changed it), so the app should show hasAccess, not the status alone.
 */
public record CareRelationshipResponse(long id, long patientId, String patientFirstName, String patientLastName,
        long memberId, String memberFirstName, String memberLastName, String memberEmail, String memberRole,
        String status, boolean canViewGlucose, boolean canViewMeals, boolean canViewMedications,
        boolean canViewActivity, boolean canViewReports, boolean canReceiveAlerts, boolean canAddRecommendations,
        Instant invitedAt, Instant respondedAt, Instant revokedAt, Instant expiresAt, boolean hasAccess) {

    /** now: the current time, from the application's Clock (decides hasAccess). */
    public static CareRelationshipResponse from(CareRelationshipRow row, Instant now) {
        Permissions p = row.permissions();
        return new CareRelationshipResponse(row.id(), row.patientId(), row.patientFirstName(), row.patientLastName(),
                row.memberId(), row.memberFirstName(), row.memberLastName(), row.memberEmail(), row.memberRole(),
                row.status(), p.viewGlucose(), p.viewMeals(), p.viewMedications(), p.viewActivity(), p.viewReports(),
                p.receiveAlerts(), p.addRecommendations(), row.invitedAt(), row.respondedAt(), row.revokedAt(),
                row.expiresAt(),
                "ACTIVE".equals(row.status()) && (row.expiresAt() == null || row.expiresAt().isAfter(now)));
    }
}

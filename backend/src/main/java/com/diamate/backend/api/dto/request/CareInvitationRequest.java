package com.diamate.backend.api.dto.request;

import java.time.Instant;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Body of POST /api/v1/care-relationships: a patient invites a clinician or caregiver by the email of their DiaMate
 * account. The role comes from that account. Every permission is optional; when left out, the defaults of the
 * care_relationships table apply: all data and alerts are shared, adding recommendations is not.
 *
 * expiresAt (optional, ISO-8601) limits the sharing in time, e.g. a relative who looks after the patient for a week:
 * from that moment on the member sees nothing, without anyone having to revoke. Left out = no end date.
 */
public record CareInvitationRequest(
        @NotBlank(message = "Email is required")
        @Email(message = "Email format is invalid")
        @Size(max = 150, message = "Email must be at most 150 characters")
        String memberEmail,
        Boolean canViewGlucose,
        Boolean canViewMeals,
        Boolean canViewMedications,
        Boolean canViewActivity,
        Boolean canViewReports,
        Boolean canReceiveAlerts,
        Boolean canAddRecommendations,
        Instant expiresAt) {
}

package com.diamate.backend.api.dto.request;

import java.time.Instant;

/**
 * Body of PATCH /api/v1/care-relationships/{id}: the permissions the patient wants to change. A field left out (or
 * null) keeps its current value, so {"canViewMeals": false} stops sharing meals and changes nothing else.
 *
 * The end date of the sharing changes the same way: expiresAt sets a new one (sooner or later, also on a relationship
 * that has just expired, which brings the access back), {"removeExpiry": true} removes it. Both together are a 400.
 */
public record CarePermissionsRequest(
        Boolean canViewGlucose,
        Boolean canViewMeals,
        Boolean canViewMedications,
        Boolean canViewActivity,
        Boolean canViewReports,
        Boolean canReceiveAlerts,
        Boolean canAddRecommendations,
        Instant expiresAt,
        Boolean removeExpiry) {
}

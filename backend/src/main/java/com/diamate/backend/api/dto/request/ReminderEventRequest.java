package com.diamate.backend.api.dto.request;

import java.time.Instant;

import com.diamate.backend.entity.ReminderEventStatus;

import jakarta.validation.constraints.NotNull;

/**
 * Body of POST /patients/{patientId}/reminders/{reminderId}/events: what the patient did with one occurrence.
 * Example: {"scheduledFor":"2026-11-23T05:00:00Z","status":"TAKEN"}.
 * status is TAKEN, SKIPPED or MISSED (the others are the backend's own, 400 here). Sending the same scheduledFor again
 * changes that occurrence (e.g. MISSED, then TAKEN later) instead of adding one.
 */
public record ReminderEventRequest(

        @NotNull(message = "scheduledFor is required")
        Instant scheduledFor,

        @NotNull(message = "Status is required")
        ReminderEventStatus status) {
}

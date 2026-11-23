package com.diamate.backend.entity;

/**
 * reminder_events.status. Must match the CHECK constraint. The app reports TAKEN, SKIPPED or MISSED for an occurrence
 * (ReminderEventRequest); PENDING, SENT and SNOOZED are kept for a later server-side scheduler.
 */
public enum ReminderEventStatus {
    PENDING,
    SENT,
    TAKEN,
    MISSED,
    SNOOZED,
    SKIPPED
}

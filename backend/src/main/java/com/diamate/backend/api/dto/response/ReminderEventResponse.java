package com.diamate.backend.api.dto.response;

import java.time.Instant;

import com.diamate.backend.entity.ReminderEvent;
import com.diamate.backend.entity.ReminderEventStatus;

// One occurrence of a reminder and what the patient did with it (acknowledgedAt = when it was answered).
public record ReminderEventResponse(long id, long reminderId, long patientId, Instant scheduledFor,
        ReminderEventStatus status, Instant acknowledgedAt) {

    public static ReminderEventResponse from(ReminderEvent event) {
        return new ReminderEventResponse(event.getId(), event.getReminderId(), event.getPatientId(),
                event.getScheduledFor(), event.getStatus(), event.getAcknowledgedAt());
    }
}

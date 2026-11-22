package com.diamate.backend.api.dto.response;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.List;

import com.diamate.backend.entity.Reminder;
import com.diamate.backend.entity.ReminderType;

// One reminder of a patient. daysOfWeek in week order (MONDAY first); missedCount = occurrences reported as MISSED;
// lastTriggeredAt = the latest occurrence reported for it.
public record ReminderResponse(long id, long patientId, ReminderType reminderType, String medicationName,
        String dosage, String message, LocalTime scheduledTime, List<DayOfWeek> daysOfWeek, String timezone,
        boolean active, int missedCount, Instant lastTriggeredAt, Instant createdAt, Instant updatedAt) {

    public static ReminderResponse from(Reminder reminder) {
        return new ReminderResponse(reminder.getId(), reminder.getPatientId(), reminder.getReminderType(),
                reminder.getMedicationName(), reminder.getDosage(), reminder.getMessage(),
                reminder.getScheduledTime(), days(reminder.getDaysOfWeek()), reminder.getTimezone(),
                reminder.isActive(), reminder.getMissedCount(), reminder.getLastTriggeredAt(),
                reminder.getCreatedAt(), reminder.getUpdatedAt());
    }

    /** "MON,WED" (the column) -> [MONDAY, WEDNESDAY]. */
    static List<DayOfWeek> days(String column) {
        return Arrays.stream(column.split(","))
                .map(String::trim)
                .filter(day -> !day.isEmpty())
                .map(day -> Arrays.stream(DayOfWeek.values())
                        .filter(d -> d.name().startsWith(day))
                        .findFirst()
                        .orElseThrow(() -> new IllegalStateException("Unknown day in reminders.days_of_week: " + day)))
                .sorted()
                .toList();
    }
}

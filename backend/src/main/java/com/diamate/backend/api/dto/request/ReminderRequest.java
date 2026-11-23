package com.diamate.backend.api.dto.request;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;

import com.diamate.backend.entity.ReminderType;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Body of POST / PUT for reminders. PUT replaces all fields, like the logs.
 *
 * Example: {"reminderType":"MEDICATION","medicationName":"Metformin","dosage":"500 mg","scheduledTime":"08:00",
 * "daysOfWeek":["MONDAY","WEDNESDAY","FRIDAY"],"timezone":"Europe/Istanbul"}
 *
 * reminderType defaults to MEDICATION, timezone to UTC, active to true. medicationName is required for a MEDICATION
 * reminder (checked in ReminderService, 400 errors.medicationName).
 */
public record ReminderRequest(

        ReminderType reminderType, // MEDICATION, GLUCOSE_CHECK, MEAL, APPOINTMENT, OTHER

        @Size(max = 100, message = "Medication name must be at most 100 characters")
        String medicationName,

        @Size(max = 50, message = "Dosage must be at most 50 characters")
        String dosage,

        @Size(max = 255, message = "Message must be at most 255 characters")
        String message,

        @NotNull(message = "Time is required")
        LocalTime scheduledTime, // "08:00", local time in timezone

        @NotEmpty(message = "Choose at least one day")
        @Size(max = 7, message = "A week has 7 days")
        List<@NotNull(message = "Day must not be empty") DayOfWeek> daysOfWeek,

        @Size(max = 50, message = "Time zone must be at most 50 characters")
        String timezone, // "Europe/Istanbul" or "+03:00"

        Boolean active) {
}

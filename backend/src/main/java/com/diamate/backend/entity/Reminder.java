package com.diamate.backend.entity;

import java.time.Instant;
import java.time.LocalTime;

import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Maps reminders: a repeating reminder of a patient (take a medicine, check glucose ...) at a time of day on some days
 * of the week. The phone schedules the notification itself; the backend keeps the definition so it survives a new
 * phone and the care team can see the medication plan.
 * Not mapped yet: medication_id (the medications list has no endpoint; the reminder carries the name and dosage).
 */
@Entity
@Table(name = "reminders")
public class Reminder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "patient_id", nullable = false, updatable = false)
    private Long patientId;

    @Enumerated(EnumType.STRING)
    @Column(name = "reminder_type", nullable = false, length = 20)
    private ReminderType reminderType;

    @Column(name = "medication_name", length = 100)
    private String medicationName;

    @Column(length = 50)
    private String dosage;

    @Column(length = 255)
    private String message;

    // Local time of day in `timezone`.
    @Column(name = "scheduled_time", nullable = false)
    private LocalTime scheduledTime;

    // "MON,TUE,WED,THU,FRI,SAT,SUN" order, only the chosen days (ReminderService writes it).
    @Column(name = "days_of_week", nullable = false, length = 27)
    private String daysOfWeek;

    // An IANA zone ("Europe/Istanbul") or an offset ("+03:00"), as sent by the phone.
    @Column(nullable = false, length = 50)
    private String timezone;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "missed_count", nullable = false)
    private int missedCount;

    @Column(name = "last_triggered_at")
    private Instant lastTriggeredAt;

    // Filled by the database (DEFAULT now()).
    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    // Filled by the database (DEFAULT now() and the trg_reminders_updated trigger).
    @Generated(event = { EventType.INSERT, EventType.UPDATE })
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Reminder() {
        // required by JPA
    }

    public Reminder(long patientId) {
        this.patientId = patientId;
    }

    /** All editable fields at once (PUT replaces the whole reminder). */
    public void update(ReminderType reminderType, String medicationName, String dosage, String message,
            LocalTime scheduledTime, String daysOfWeek, String timezone, boolean active) {
        this.reminderType = reminderType;
        this.medicationName = medicationName;
        this.dosage = dosage;
        this.message = message;
        this.scheduledTime = scheduledTime;
        this.daysOfWeek = daysOfWeek;
        this.timezone = timezone;
        this.active = active;
    }

    /** An occurrence was reported: remembers when, and counts it when it was missed. */
    public void occurrenceReported(Instant scheduledFor, boolean newlyMissed) {
        if (lastTriggeredAt == null || scheduledFor.isAfter(lastTriggeredAt)) {
            lastTriggeredAt = scheduledFor;
        }
        if (newlyMissed) {
            missedCount++;
        }
    }

    public Long getId() {
        return id;
    }

    public Long getPatientId() {
        return patientId;
    }

    public ReminderType getReminderType() {
        return reminderType;
    }

    public String getMedicationName() {
        return medicationName;
    }

    public String getDosage() {
        return dosage;
    }

    public String getMessage() {
        return message;
    }

    public LocalTime getScheduledTime() {
        return scheduledTime;
    }

    public String getDaysOfWeek() {
        return daysOfWeek;
    }

    public String getTimezone() {
        return timezone;
    }

    public boolean isActive() {
        return active;
    }

    public int getMissedCount() {
        return missedCount;
    }

    public Instant getLastTriggeredAt() {
        return lastTriggeredAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}

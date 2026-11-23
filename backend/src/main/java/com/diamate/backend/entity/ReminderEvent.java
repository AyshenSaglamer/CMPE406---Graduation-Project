package com.diamate.backend.entity;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Maps reminder_events: one occurrence of a reminder (scheduled_for) and what the patient did with it. Unique per
 * (reminder_id, scheduled_for), so reporting the same occurrence again changes the row instead of adding one.
 * The view v_reminder_adherence_30d counts these rows. Not mapped yet: sent_at and snoozed_until (no scheduler).
 */
@Entity
@Table(name = "reminder_events")
public class ReminderEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "reminder_id", nullable = false, updatable = false)
    private Long reminderId;

    @Column(name = "patient_id", nullable = false, updatable = false)
    private Long patientId;

    @Column(name = "scheduled_for", nullable = false, updatable = false)
    private Instant scheduledFor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private ReminderEventStatus status = ReminderEventStatus.PENDING;

    // When the patient answered (Taken / Skip) or the app marked it missed.
    @Column(name = "acknowledged_at")
    private Instant acknowledgedAt;

    protected ReminderEvent() {
        // required by JPA
    }

    public ReminderEvent(long reminderId, long patientId, Instant scheduledFor) {
        this.reminderId = reminderId;
        this.patientId = patientId;
        this.scheduledFor = scheduledFor;
    }

    public void answer(ReminderEventStatus status, Instant at) {
        this.status = status;
        this.acknowledgedAt = at;
    }

    public Long getId() {
        return id;
    }

    public Long getReminderId() {
        return reminderId;
    }

    public Long getPatientId() {
        return patientId;
    }

    public Instant getScheduledFor() {
        return scheduledFor;
    }

    public ReminderEventStatus getStatus() {
        return status;
    }

    public Instant getAcknowledgedAt() {
        return acknowledgedAt;
    }
}

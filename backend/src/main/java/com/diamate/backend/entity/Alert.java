package com.diamate.backend.entity;

import java.math.BigDecimal;
import java.time.Instant;

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
 * Maps alerts. The backend creates glucose alerts (LOW / HIGH and the urgent ones) when a reading is saved;
 * the patient or the care team acknowledges / resolves them (AlertService).
 * Not mapped yet: reminder_event_id and the follow-up columns (no endpoint uses them).
 */
@Entity
@Table(name = "alerts")
public class Alert {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "patient_id", nullable = false, updatable = false)
    private Long patientId;

    @Enumerated(EnumType.STRING)
    @Column(name = "alert_type", nullable = false, length = 20, updatable = false)
    private AlertType alertType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10, updatable = false)
    private AlertSeverity severity;

    @Column(name = "glucose_log_id", updatable = false)
    private Long glucoseLogId;

    @Column(name = "value_mgdl", precision = 5, scale = 1, updatable = false)
    private BigDecimal valueMgdl;

    @Column(nullable = false, length = 500, updatable = false)
    private String message;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 15)
    private AlertStatus status = AlertStatus.OPEN;

    // Filled by the database (DEFAULT now()).
    @Generated(event = EventType.INSERT)
    @Column(name = "triggered_at", nullable = false)
    private Instant triggeredAt;

    // Who handled the alert first (acknowledged it, or resolved it directly) and when.
    @Column(name = "acknowledged_by")
    private Long acknowledgedBy;

    @Column(name = "acknowledged_at")
    private Instant acknowledgedAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    // Who resolved it (V7). Like the other handling columns, written only by AlertRepository's conditional updates.
    @Column(name = "resolved_by")
    private Long resolvedBy;

    protected Alert() {
        // required by JPA
    }

    public Alert(long patientId, AlertType alertType, AlertSeverity severity, Long glucoseLogId, int valueMgdl,
            String message) {
        this.patientId = patientId;
        this.alertType = alertType;
        this.severity = severity;
        this.glucoseLogId = glucoseLogId;
        this.valueMgdl = BigDecimal.valueOf(valueMgdl);
        this.message = message;
    }

    public Long getId() {
        return id;
    }

    public Long getPatientId() {
        return patientId;
    }

    public AlertType getAlertType() {
        return alertType;
    }

    public AlertSeverity getSeverity() {
        return severity;
    }

    public Long getGlucoseLogId() {
        return glucoseLogId;
    }

    public BigDecimal getValueMgdl() {
        return valueMgdl;
    }

    public String getMessage() {
        return message;
    }

    public AlertStatus getStatus() {
        return status;
    }

    public Instant getTriggeredAt() {
        return triggeredAt;
    }

    public Long getAcknowledgedBy() {
        return acknowledgedBy;
    }

    public Instant getAcknowledgedAt() {
        return acknowledgedAt;
    }

    public Instant getResolvedAt() {
        return resolvedAt;
    }

    public Long getResolvedBy() {
        return resolvedBy;
    }

    // No setters for the status: changes go through AlertRepository's single conditional UPDATEs (acknowledgeIfOpen,
    // resolveIfNotClosed), so two people handling the same alert at once, or the backend dismissing it meanwhile,
    // cannot overwrite each other.
}

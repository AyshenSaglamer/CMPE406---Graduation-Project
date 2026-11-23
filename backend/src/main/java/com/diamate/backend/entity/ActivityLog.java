package com.diamate.backend.entity;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.SQLRestriction;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

/** Maps activity_logs (one exercise session; raw wearable samples live in wearable_samples). */
@Entity
@Table(name = "activity_logs")
@SQLRestriction("deleted_at IS NULL")
public class ActivityLog extends PatientLog {

    // Free text, e.g. "walking", "swimming".
    @Column(name = "activity_type", nullable = false, length = 50)
    private String activityType;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "duration_minutes", precision = 6, scale = 1)
    private BigDecimal durationMinutes;

    private Integer steps;

    // smallint in the database, so Short here (ddl-auto: validate checks the type).
    @Column(name = "avg_heart_rate")
    private Short avgHeartRate;

    @Column(name = "calories_kcal", precision = 7, scale = 1)
    private BigDecimal caloriesKcal;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private ActivityIntensity intensity;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20, updatable = false)
    private ActivitySource source;

    protected ActivityLog() {
        // required by JPA
    }

    public ActivityLog(long patientId, UUID clientUuid, ActivitySource source) {
        super(patientId, clientUuid);
        this.source = source;
    }

    public void update(String activityType, Instant startedAt, BigDecimal durationMinutes, Integer steps,
            Short avgHeartRate, BigDecimal caloriesKcal, ActivityIntensity intensity, String notes) {
        this.activityType = activityType;
        this.startedAt = startedAt;
        this.durationMinutes = durationMinutes;
        this.steps = steps;
        this.avgHeartRate = avgHeartRate;
        this.caloriesKcal = caloriesKcal;
        this.intensity = intensity;
        setNotes(notes);
    }

    public String getActivityType() {
        return activityType;
    }

    public Instant getStartedAt() {
        return startedAt;
    }

    public BigDecimal getDurationMinutes() {
        return durationMinutes;
    }

    public Integer getSteps() {
        return steps;
    }

    public Short getAvgHeartRate() {
        return avgHeartRate;
    }

    public BigDecimal getCaloriesKcal() {
        return caloriesKcal;
    }

    public ActivityIntensity getIntensity() {
        return intensity;
    }

    public ActivitySource getSource() {
        return source;
    }
}

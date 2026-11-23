package com.diamate.backend.entity;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.SQLRestriction;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

/** Maps glucose_logs. Values are always mg/dL. */
@Entity
@Table(name = "glucose_logs")
@SQLRestriction("deleted_at IS NULL")
public class GlucoseLog extends PatientLog {

    @Column(name = "glucose_value", nullable = false)
    private int glucoseValue;

    @Column(name = "measurement_time", nullable = false)
    private Instant measurementTime;

    @Enumerated(EnumType.STRING)
    @Column(name = "meal_context", length = 20)
    private MealContext mealContext;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20, updatable = false)
    private GlucoseSource source;

    // Who typed the value in (today always the patient; kept for a later caregiver entry feature).
    @Column(name = "entered_by", updatable = false)
    private Long enteredBy;

    protected GlucoseLog() {
        // required by JPA
    }

    public GlucoseLog(long patientId, UUID clientUuid, GlucoseSource source, long enteredBy) {
        super(patientId, clientUuid);
        this.source = source;
        this.enteredBy = enteredBy;
    }

    public void update(int glucoseValue, Instant measurementTime, MealContext mealContext, String notes) {
        this.glucoseValue = glucoseValue;
        this.measurementTime = measurementTime;
        this.mealContext = mealContext;
        setNotes(notes);
    }

    public int getGlucoseValue() {
        return glucoseValue;
    }

    public Instant getMeasurementTime() {
        return measurementTime;
    }

    public MealContext getMealContext() {
        return mealContext;
    }

    public GlucoseSource getSource() {
        return source;
    }

    public Long getEnteredBy() {
        return enteredBy;
    }
}

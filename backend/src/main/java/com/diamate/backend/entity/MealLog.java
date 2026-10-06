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

/**
 * Maps meal_logs. Not mapped yet: photo_url and ai_confidence (photo recognition comes later) and the
 * meal_log_items table (individual foods of a meal).
 */
@Entity
@Table(name = "meal_logs")
@SQLRestriction("deleted_at IS NULL")
public class MealLog extends PatientLog {

    @Enumerated(EnumType.STRING)
    @Column(name = "meal_type", nullable = false, length = 20)
    private MealType mealType;

    @Column(name = "eaten_at", nullable = false)
    private Instant eatenAt;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "carbs_g", precision = 6, scale = 1)
    private BigDecimal carbsG;

    @Column(name = "calories_kcal", precision = 7, scale = 1)
    private BigDecimal caloriesKcal;

    @Column(name = "protein_g", precision = 6, scale = 1)
    private BigDecimal proteinG;

    @Column(name = "fat_g", precision = 6, scale = 1)
    private BigDecimal fatG;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20, updatable = false)
    private MealSource source;

    protected MealLog() {
        // required by JPA
    }

    public MealLog(long patientId, UUID clientUuid, MealSource source) {
        super(patientId, clientUuid);
        this.source = source;
    }

    public void update(MealType mealType, Instant eatenAt, String description, BigDecimal carbsG,
            BigDecimal caloriesKcal, BigDecimal proteinG, BigDecimal fatG, String notes) {
        this.mealType = mealType;
        this.eatenAt = eatenAt;
        this.description = description;
        this.carbsG = carbsG;
        this.caloriesKcal = caloriesKcal;
        this.proteinG = proteinG;
        this.fatG = fatG;
        setNotes(notes);
    }

    public MealType getMealType() {
        return mealType;
    }

    public Instant getEatenAt() {
        return eatenAt;
    }

    public String getDescription() {
        return description;
    }

    public BigDecimal getCarbsG() {
        return carbsG;
    }

    public BigDecimal getCaloriesKcal() {
        return caloriesKcal;
    }

    public BigDecimal getProteinG() {
        return proteinG;
    }

    public BigDecimal getFatG() {
        return fatG;
    }

    public MealSource getSource() {
        return source;
    }
}

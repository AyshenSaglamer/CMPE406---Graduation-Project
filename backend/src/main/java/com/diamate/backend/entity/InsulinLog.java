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

/** Maps insulin_logs. Doses in units (numeric, so 0.5 U steps are possible). */
@Entity
@Table(name = "insulin_logs")
@SQLRestriction("deleted_at IS NULL")
public class InsulinLog extends PatientLog {

    @Column(name = "dose_units", nullable = false, precision = 6, scale = 2)
    private BigDecimal doseUnits;

    @Enumerated(EnumType.STRING)
    @Column(name = "insulin_type", nullable = false, length = 20)
    private InsulinType insulinType;

    @Enumerated(EnumType.STRING)
    @Column(name = "delivery_method", nullable = false, length = 20)
    private InsulinDeliveryMethod deliveryMethod;

    @Column(name = "product_name", length = 100)
    private String productName;

    @Column(name = "administered_at", nullable = false)
    private Instant administeredAt;

    // Optional link to the meal this dose was for (must belong to the same patient; checked in the service).
    @Column(name = "meal_log_id")
    private Long mealLogId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20, updatable = false)
    private InsulinSource source;

    @Column(name = "entered_by", updatable = false)
    private Long enteredBy;

    protected InsulinLog() {
        // required by JPA
    }

    public InsulinLog(long patientId, UUID clientUuid, InsulinSource source, long enteredBy) {
        super(patientId, clientUuid);
        this.source = source;
        this.enteredBy = enteredBy;
    }

    public void update(BigDecimal doseUnits, InsulinType insulinType, InsulinDeliveryMethod deliveryMethod,
            String productName, Instant administeredAt, Long mealLogId, String notes) {
        this.doseUnits = doseUnits;
        this.insulinType = insulinType;
        this.deliveryMethod = deliveryMethod;
        this.productName = productName;
        this.administeredAt = administeredAt;
        this.mealLogId = mealLogId;
        setNotes(notes);
    }

    public BigDecimal getDoseUnits() {
        return doseUnits;
    }

    public InsulinType getInsulinType() {
        return insulinType;
    }

    public InsulinDeliveryMethod getDeliveryMethod() {
        return deliveryMethod;
    }

    public String getProductName() {
        return productName;
    }

    public Instant getAdministeredAt() {
        return administeredAt;
    }

    public Long getMealLogId() {
        return mealLogId;
    }

    public InsulinSource getSource() {
        return source;
    }

    public Long getEnteredBy() {
        return enteredBy;
    }
}

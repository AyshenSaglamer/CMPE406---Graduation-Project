package com.diamate.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.diamate.backend.entity.Alert;
import com.diamate.backend.entity.AlertStatus;

public interface AlertRepository extends JpaRepository<Alert, Long> {

    /**
     * Database helper fn_glucose_alert_type: compares the value with the patient's own thresholds in
     * patient_profiles and returns URGENT_LOW / LOW / HIGH / URGENT_HIGH, or nothing when the value is in range.
     */
    @Query(value = "select fn_glucose_alert_type(:patientId, :value)", nativeQuery = true)
    Optional<String> classifyGlucose(@Param("patientId") long patientId, @Param("value") int value);

    /** Changes the status of a reading's alerts that are in currentStatus (e.g. OPEN -> DISMISSED). */
    @Modifying
    @Query("""
            update Alert a set a.status = :newStatus
            where a.glucoseLogId = :glucoseLogId and a.status = :currentStatus""")
    int changeStatusOfReadingAlerts(@Param("glucoseLogId") long glucoseLogId,
            @Param("currentStatus") AlertStatus currentStatus, @Param("newStatus") AlertStatus newStatus);
}

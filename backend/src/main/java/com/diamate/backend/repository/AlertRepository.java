package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Collection;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

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

    // patient_id + time range: uses the index ix_alerts_patient_time. "id desc" keeps the order stable between pages.
    // Read-only transaction for the page and count queries, like the log repositories.
    @Transactional(readOnly = true)
    @Query("""
            select a from Alert a
            where a.patientId = :patientId and a.triggeredAt >= :from and a.triggeredAt < :to
            order by a.triggeredAt desc, a.id desc""")
    Page<Alert> findInRange(@Param("patientId") long patientId, @Param("from") Instant from, @Param("to") Instant to,
            Pageable pageable);

    // Same as findInRange, only alerts in one status (e.g. the OPEN ones for the care team's list).
    @Transactional(readOnly = true)
    @Query("""
            select a from Alert a
            where a.patientId = :patientId and a.status = :status and a.triggeredAt >= :from and a.triggeredAt < :to
            order by a.triggeredAt desc, a.id desc""")
    Page<Alert> findInRangeWithStatus(@Param("patientId") long patientId, @Param("status") AlertStatus status,
            @Param("from") Instant from, @Param("to") Instant to, Pageable pageable);

    // Both ids are required, so an alert id from another patient is "not found".
    Optional<Alert> findByIdAndPatientId(long id, long patientId);

    // ---- status changes: one conditional UPDATE each, so a change based on an outdated read cannot win ----

    // OPEN -> ACKNOWLEDGED. 0 rows when the alert is no longer OPEN (someone else acknowledged or closed it, or the
    // backend dismissed it because its reading was deleted or corrected).
    @Transactional
    @Modifying
    @Query("""
            update Alert a
            set a.status = com.diamate.backend.entity.AlertStatus.ACKNOWLEDGED,
                a.acknowledgedBy = :userId, a.acknowledgedAt = :at
            where a.id = :id and a.patientId = :patientId
              and a.status = com.diamate.backend.entity.AlertStatus.OPEN""")
    int acknowledgeIfOpen(@Param("id") long id, @Param("patientId") long patientId, @Param("userId") long userId,
            @Param("at") Instant at);

    // OPEN or ACKNOWLEDGED -> RESOLVED, with who and when. An alert resolved without being acknowledged first also
    // gets the first-handler columns (the first person who acted on it). 0 rows when it is RESOLVED or DISMISSED.
    @Transactional
    @Modifying
    @Query("""
            update Alert a
            set a.status = com.diamate.backend.entity.AlertStatus.RESOLVED,
                a.resolvedBy = :userId, a.resolvedAt = :at,
                a.acknowledgedBy = coalesce(a.acknowledgedBy, :userId),
                a.acknowledgedAt = coalesce(a.acknowledgedAt, :at)
            where a.id = :id and a.patientId = :patientId
              and a.status in (com.diamate.backend.entity.AlertStatus.OPEN,
                               com.diamate.backend.entity.AlertStatus.ACKNOWLEDGED)""")
    int resolveIfNotClosed(@Param("id") long id, @Param("patientId") long patientId, @Param("userId") long userId,
            @Param("at") Instant at);

    // ---- the care team's list: alerts of several patients in one page (GET /care-team/alerts) ----

    @Transactional(readOnly = true)
    @Query("""
            select a from Alert a
            where a.patientId in :patientIds
            order by a.triggeredAt desc, a.id desc""")
    Page<Alert> findForPatients(@Param("patientIds") Collection<Long> patientIds, Pageable pageable);

    @Transactional(readOnly = true)
    @Query("""
            select a from Alert a
            where a.patientId in :patientIds and a.status = :status
            order by a.triggeredAt desc, a.id desc""")
    Page<Alert> findForPatientsWithStatus(@Param("patientIds") Collection<Long> patientIds,
            @Param("status") AlertStatus status, Pageable pageable);
}

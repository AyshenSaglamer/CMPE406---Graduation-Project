package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.diamate.backend.entity.GlucoseLog;

// Deleted rows are already hidden by @SQLRestriction on the entity; no query needs "deleted_at IS NULL".
public interface GlucoseLogRepository extends JpaRepository<GlucoseLog, Long> {

    // patient_id + time range: uses the index ix_glucose_logs_patient_time. "id desc" keeps the order stable
    // between pages when two readings have the same time.
    @Query("""
            select g from GlucoseLog g
            where g.patientId = :patientId and g.measurementTime >= :from and g.measurementTime < :to
            order by g.measurementTime desc, g.id desc""")
    Page<GlucoseLog> findInRange(@Param("patientId") long patientId, @Param("from") Instant from,
            @Param("to") Instant to, Pageable pageable);

    // Both ids are required, so a log id from another patient is "not found".
    Optional<GlucoseLog> findByIdAndPatientId(long id, long patientId);

    Optional<GlucoseLog> findByPatientIdAndClientUuid(long patientId, UUID clientUuid);
}

package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.diamate.backend.entity.ActivityLog;

public interface ActivityLogRepository extends JpaRepository<ActivityLog, Long> {

    @Query("""
            select a from ActivityLog a
            where a.patientId = :patientId and a.startedAt >= :from and a.startedAt < :to
            order by a.startedAt desc, a.id desc""")
    Page<ActivityLog> findInRange(@Param("patientId") long patientId, @Param("from") Instant from,
            @Param("to") Instant to, Pageable pageable);

    Optional<ActivityLog> findByIdAndPatientId(long id, long patientId);

    Optional<ActivityLog> findByPatientIdAndClientUuid(long patientId, UUID clientUuid);
}

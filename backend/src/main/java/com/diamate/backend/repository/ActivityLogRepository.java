package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.entity.ActivityLog;

public interface ActivityLogRepository extends LogRepository<ActivityLog> {

    @Transactional(readOnly = true) // page query + count query in one transaction
    @Query("""
            select a from ActivityLog a
            where a.patientId = :patientId and a.startedAt >= :from and a.startedAt < :to
            order by a.startedAt desc, a.id desc""")
    Page<ActivityLog> findInRange(@Param("patientId") long patientId, @Param("from") Instant from,
            @Param("to") Instant to, Pageable pageable);

    Optional<ActivityLog> findByIdAndPatientId(long id, long patientId);
}

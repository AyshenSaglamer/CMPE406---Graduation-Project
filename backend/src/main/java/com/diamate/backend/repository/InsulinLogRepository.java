package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.diamate.backend.entity.InsulinLog;

public interface InsulinLogRepository extends JpaRepository<InsulinLog, Long> {

    @Query("""
            select i from InsulinLog i
            where i.patientId = :patientId and i.administeredAt >= :from and i.administeredAt < :to
            order by i.administeredAt desc, i.id desc""")
    Page<InsulinLog> findInRange(@Param("patientId") long patientId, @Param("from") Instant from,
            @Param("to") Instant to, Pageable pageable);

    Optional<InsulinLog> findByIdAndPatientId(long id, long patientId);

    Optional<InsulinLog> findByPatientIdAndClientUuid(long patientId, UUID clientUuid);
}

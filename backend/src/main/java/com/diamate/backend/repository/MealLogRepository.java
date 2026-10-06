package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.diamate.backend.entity.MealLog;

public interface MealLogRepository extends JpaRepository<MealLog, Long> {

    @Query("""
            select m from MealLog m
            where m.patientId = :patientId and m.eatenAt >= :from and m.eatenAt < :to
            order by m.eatenAt desc, m.id desc""")
    Page<MealLog> findInRange(@Param("patientId") long patientId, @Param("from") Instant from,
            @Param("to") Instant to, Pageable pageable);

    Optional<MealLog> findByIdAndPatientId(long id, long patientId);

    Optional<MealLog> findByPatientIdAndClientUuid(long patientId, UUID clientUuid);

    // Used when an insulin dose is linked to a meal: the meal must belong to the same patient (and not be deleted).
    boolean existsByIdAndPatientId(long id, long patientId);
}

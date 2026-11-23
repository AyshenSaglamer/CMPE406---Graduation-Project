package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.entity.InsulinLog;

public interface InsulinLogRepository extends LogRepository<InsulinLog> {

    @Transactional(readOnly = true) // page query + count query in one transaction
    @Query("""
            select i from InsulinLog i
            where i.patientId = :patientId and i.administeredAt >= :from and i.administeredAt < :to
            order by i.administeredAt desc, i.id desc""")
    Page<InsulinLog> findInRange(@Param("patientId") long patientId, @Param("from") Instant from,
            @Param("to") Instant to, Pageable pageable);

    Optional<InsulinLog> findByIdAndPatientId(long id, long patientId);

    // A meal was (soft) deleted: its doses no longer point to it. The database's ON DELETE SET NULL only runs for a
    // real DELETE, never for a soft delete. Plain SQL on purpose, so deleted doses are unlinked too.
    @Modifying
    @Query(value = "update insulin_logs set meal_log_id = null where meal_log_id = :mealLogId", nativeQuery = true)
    int unlinkMeal(@Param("mealLogId") long mealLogId);
}

package com.diamate.backend.repository;

import java.time.Instant;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.entity.ReminderEvent;

public interface ReminderEventRepository extends JpaRepository<ReminderEvent, Long> {

    // The unique key (reminder_id, scheduled_for): reporting an occurrence again finds its row.
    Optional<ReminderEvent> findByReminderIdAndScheduledFor(long reminderId, Instant scheduledFor);

    // patient_id + time range, newest first: uses ix_reminder_events_patient_time. "id desc" keeps pages stable.
    @Transactional(readOnly = true)
    @Query("""
            select e from ReminderEvent e
            where e.patientId = :patientId and e.scheduledFor >= :from and e.scheduledFor < :to
            order by e.scheduledFor desc, e.id desc""")
    Page<ReminderEvent> findInRange(@Param("patientId") long patientId, @Param("from") Instant from,
            @Param("to") Instant to, Pageable pageable);
}

package com.diamate.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.entity.Reminder;

public interface ReminderRepository extends JpaRepository<Reminder, Long> {

    /** A patient's reminders in the order of the day (uses ix_reminders_patient). A patient has a handful, no paging. */
    @Transactional(readOnly = true)
    List<Reminder> findByPatientIdOrderByScheduledTimeAscIdAsc(long patientId);

    // Both ids are required, so a reminder id of another patient is "not found".
    Optional<Reminder> findByIdAndPatientId(long id, long patientId);

    @Transactional(readOnly = true)
    long countByPatientId(long patientId);
}

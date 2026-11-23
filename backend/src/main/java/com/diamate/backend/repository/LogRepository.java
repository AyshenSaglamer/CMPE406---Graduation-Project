package com.diamate.backend.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.NoRepositoryBean;
import org.springframework.data.repository.query.Param;

/** What the four log repositories (glucose, insulin, meal, activity) have in common: the clientUuid of a new log. */
@NoRepositoryBean
public interface LogRepository<T> extends JpaRepository<T, Long> {

    Optional<T> findByPatientIdAndClientUuid(long patientId, UUID clientUuid);

    /**
     * Waits until no other transaction holds this key, then holds it until the current transaction ends. A PostgreSQL
     * advisory lock: no row or table is locked and nothing is written. Two requests with the same clientUuid at the
     * same moment (the app retrying on a slow network) then run one after the other, and the second one finds the
     * first one's log instead of running into the unique index (that was a 409, Week 2 Day 6).
     */
    @Query(value = "select count(*) from pg_advisory_xact_lock(hashtextextended(:key, 0))", nativeQuery = true)
    long lockKey(@Param("key") String key);
}

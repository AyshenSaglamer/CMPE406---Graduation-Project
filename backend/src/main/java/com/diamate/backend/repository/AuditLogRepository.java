package com.diamate.backend.repository;

import java.sql.Types;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Writes audit_logs rows. Plain SQL instead of a JPA entity: the table is append-only (the database role may only
 * INSERT and SELECT), the backend never reads it back, and "details" is jsonb, written here with a cast.
 */
@Repository
public class AuditLogRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public AuditLogRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insert(Entry entry) {
        jdbc.update("""
                INSERT INTO audit_logs (user_id, patient_id, action, entity_type, success, details, ip_address, user_agent)
                VALUES (:userId, :patientId, :action, :entityType, :success, CAST(:details AS jsonb), :ip, :userAgent)
                """,
                new MapSqlParameterSource()
                        // Types are given because these values can be null (the driver cannot guess a type from null).
                        .addValue("userId", entry.userId(), Types.BIGINT)
                        .addValue("patientId", entry.patientId(), Types.BIGINT)
                        .addValue("action", entry.action())
                        .addValue("entityType", entry.entityType(), Types.VARCHAR)
                        .addValue("success", entry.success())
                        .addValue("details", entry.detailsJson(), Types.VARCHAR)
                        .addValue("ip", entry.ipAddress(), Types.VARCHAR)
                        .addValue("userAgent", entry.userAgent(), Types.VARCHAR));
    }

    /**
     * One audit row. userId: who acted (null when unknown, e.g. a login with an unregistered email);
     * patientId: whose data was touched; detailsJson: extra facts as a JSON object, or null.
     */
    public record Entry(Long userId, Long patientId, String action, String entityType, boolean success,
            String detailsJson, String ipAddress, String userAgent) {
    }
}

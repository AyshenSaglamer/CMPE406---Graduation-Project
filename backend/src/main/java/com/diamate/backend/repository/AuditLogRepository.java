package com.diamate.backend.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Writes and reads audit_logs rows. Plain SQL instead of a JPA entity: the table is append-only (a trigger refuses
 * UPDATE, DELETE and TRUNCATE; the diamate_app role may only INSERT and SELECT), and "details" is jsonb, written with a
 * cast and read back as text.
 *
 * Two readers: the patient's own access log (who else touched their data; uses ix_audit_logs_patient_time) and the
 * ADMIN's filtered search. Both are newest first and paged with LIMIT / OFFSET.
 */
@Repository
public class AuditLogRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public AuditLogRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insert(Entry entry) {
        jdbc.update("""
                INSERT INTO audit_logs (user_id, patient_id, action, entity_type, entity_id, success, details, ip_address,
                                        user_agent)
                VALUES (:userId, :patientId, :action, :entityType, :entityId, :success, CAST(:details AS jsonb), :ip,
                        :userAgent)
                """,
                new MapSqlParameterSource()
                        // Types are given because these values can be null (the driver cannot guess a type from null).
                        .addValue("userId", entry.userId(), Types.BIGINT)
                        .addValue("patientId", entry.patientId(), Types.BIGINT)
                        .addValue("action", entry.action())
                        .addValue("entityType", entry.entityType(), Types.VARCHAR)
                        .addValue("entityId", entry.entityId(), Types.VARCHAR)
                        .addValue("success", entry.success())
                        .addValue("details", entry.detailsJson(), Types.VARCHAR)
                        .addValue("ip", entry.ipAddress(), Types.VARCHAR)
                        .addValue("userAgent", entry.userAgent(), Types.VARCHAR));
    }

    /** Rows about this patient written by someone else (or by nobody known), in [from, to). */
    public long countForPatient(long patientId, Instant from, Instant to) {
        Long count = jdbc.queryForObject("SELECT count(*) FROM audit_logs a WHERE " + PATIENT_FILTER,
                windowParams(from, to).addValue("patient", patientId), Long.class);
        return count != null ? count : 0;
    }

    public List<PatientAccessRow> findForPatient(long patientId, Instant from, Instant to, long offset, int limit) {
        return jdbc.query("""
                SELECT a.id, a.created_at, a.user_id, u.first_name, u.last_name, u.role, a.action, a.entity_type,
                       a.entity_id, a.success, a.details::text AS details
                FROM audit_logs a
                LEFT JOIN users u ON u.id = a.user_id
                WHERE """ + PATIENT_FILTER + """
                 ORDER BY a.created_at DESC, a.id DESC
                LIMIT :limit OFFSET :offset
                """,
                windowParams(from, to).addValue("patient", patientId).addValue("limit", limit)
                        .addValue("offset", offset),
                (rs, i) -> new PatientAccessRow(rs.getLong("id"), instant(rs, "created_at"),
                        nullableLong(rs, "user_id"),
                        rs.getString("first_name"), rs.getString("last_name"), rs.getString("role"),
                        rs.getString("action"), rs.getString("entity_type"), rs.getString("entity_id"),
                        rs.getBoolean("success"), rs.getString("details")));
    }

    /** ADMIN search; every filter is optional (null = any). */
    public long countMatching(Filter filter) {
        Long count = jdbc.queryForObject("SELECT count(*) FROM audit_logs a WHERE " + ADMIN_FILTER,
                filterParams(filter), Long.class);
        return count != null ? count : 0;
    }

    public List<AuditRow> findMatching(Filter filter, long offset, int limit) {
        return jdbc.query("""
                SELECT a.id, a.created_at, a.user_id, a.patient_id, a.action, a.entity_type, a.entity_id, a.success,
                       a.details::text AS details, a.ip_address, a.user_agent
                FROM audit_logs a
                WHERE """ + ADMIN_FILTER + """
                 ORDER BY a.created_at DESC, a.id DESC
                LIMIT :limit OFFSET :offset
                """,
                filterParams(filter).addValue("limit", limit).addValue("offset", offset),
                (rs, i) -> new AuditRow(rs.getLong("id"), instant(rs, "created_at"), nullableLong(rs, "user_id"),
                        nullableLong(rs, "patient_id"), rs.getString("action"), rs.getString("entity_type"),
                        rs.getString("entity_id"), rs.getBoolean("success"), rs.getString("details"),
                        rs.getString("ip_address"), rs.getString("user_agent")));
    }

    private static final String WINDOW_FILTER = " a.created_at >= :from AND a.created_at < :to ";

    // Someone else's action on this patient's data; the patient's own actions (their logins, edits) are not shown.
    // A refused attempt is shown only if it came from someone in this patient's care team at that time, or who left
    // it less than 30 days before: anyone can send requests with a random patient id, and those must not fill the
    // patient's log or put a self-chosen name in it (nor can a former member keep doing so). They stay in
    // audit_logs for the ADMIN search.
    private static final String PATIENT_FILTER = " " + """
             a.patient_id = :patient AND (a.user_id IS NULL OR a.user_id <> :patient)
             AND (a.success OR a.user_id IS NULL OR EXISTS (
                     SELECT 1 FROM care_relationships r
                     WHERE r.patient_id = a.patient_id AND r.member_id = a.user_id
                       AND r.invited_at <= a.created_at
                       AND (r.status IN ('PENDING', 'ACTIVE')
                            OR COALESCE(r.revoked_at, r.responded_at) > a.created_at - INTERVAL '30 days')))
             AND""" + WINDOW_FILTER;

    private static final String ADMIN_FILTER = WINDOW_FILTER + """
             AND (CAST(:user AS bigint) IS NULL OR a.user_id = :user)
             AND (CAST(:patient AS bigint) IS NULL OR a.patient_id = :patient)
             AND (CAST(:action AS varchar) IS NULL OR a.action = :action)
             AND (CAST(:success AS boolean) IS NULL OR a.success = :success)
            """;

    private static MapSqlParameterSource windowParams(Instant from, Instant to) {
        return new MapSqlParameterSource()
                .addValue("from", from.atOffset(ZoneOffset.UTC), Types.TIMESTAMP_WITH_TIMEZONE)
                .addValue("to", to.atOffset(ZoneOffset.UTC), Types.TIMESTAMP_WITH_TIMEZONE);
    }

    private static MapSqlParameterSource filterParams(Filter filter) {
        return windowParams(filter.from(), filter.to())
                .addValue("user", filter.userId(), Types.BIGINT)
                .addValue("patient", filter.patientId(), Types.BIGINT)
                .addValue("action", filter.action(), Types.VARCHAR)
                .addValue("success", filter.success(), Types.BOOLEAN);
    }

    private static Long nullableLong(ResultSet rs, String column) throws SQLException {
        long value = rs.getLong(column);
        return rs.wasNull() ? null : value;
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        Timestamp value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    /** ADMIN search filters; from and to are required (the service fills a default window). */
    public record Filter(Instant from, Instant to, Long userId, Long patientId, String action, Boolean success) {
    }

    /** A row of the patient's access log, with the name and role of whoever acted (null if unknown or deleted). */
    public record PatientAccessRow(long id, Instant createdAt, Long actorId, String actorFirstName,
            String actorLastName, String actorRole, String action, String entityType, String entityId,
            boolean success, String detailsJson) {
    }

    /** A full audit row, as the ADMIN sees it. */
    public record AuditRow(long id, Instant createdAt, Long userId, Long patientId, String action, String entityType,
            String entityId, boolean success, String detailsJson, String ipAddress, String userAgent) {
    }

    /**
     * One audit row. userId: who acted (null when unknown, e.g. a login with an unregistered email);
     * patientId: whose data was touched; detailsJson: extra facts as a JSON object, or null.
     */
    public record Entry(Long userId, Long patientId, String action, String entityType, String entityId,
            boolean success, String detailsJson, String ipAddress, String userAgent) {
    }
}

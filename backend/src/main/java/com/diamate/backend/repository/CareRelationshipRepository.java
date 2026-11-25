package com.diamate.backend.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

/**
 * care_relationships: who shares which data with which clinician or caregiver. Plain SQL like
 * PatientAccessRepository, because fn_can_access() reads this table directly and the rows are always shown with the
 * names of both people.
 *
 * Status changes are single conditional UPDATEs ("... WHERE status = 'PENDING'") instead of read-change-save, so two
 * requests at the same moment (accept and revoke, or two devices) cannot overwrite each other: the second one changes
 * 0 rows and the service answers from what is there now. The database trigger care_relationship_guard() checks that
 * member_role matches the member's account and fills responded_at / revoked_at; set_updated_at() fills updated_at.
 */
@Repository
public class CareRelationshipRepository {

    private static final String SELECT = """
            SELECT r.id, r.patient_id, p.first_name AS patient_first_name, p.last_name AS patient_last_name,
                   r.member_id, m.first_name AS member_first_name, m.last_name AS member_last_name,
                   m.email AS member_email, r.member_role, r.status,
                   r.can_view_glucose, r.can_view_meals, r.can_view_medications, r.can_view_activity,
                   r.can_view_reports, r.can_receive_alerts, r.can_add_recommendations,
                   r.invited_by, r.invited_at, r.responded_at, r.revoked_at, r.expires_at
            FROM care_relationships r
            JOIN users p ON p.id = r.patient_id
            JOIN users m ON m.id = r.member_id
            """;

    private static final RowMapper<CareRelationshipRow> ROW = CareRelationshipRepository::row;

    private final NamedParameterJdbcTemplate jdbc;

    public CareRelationshipRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional(readOnly = true)
    public Optional<CareRelationshipRow> findById(long id) {
        return jdbc.query(SELECT + " WHERE r.id = :id", Map.of("id", id), ROW).stream().findFirst();
    }

    /**
     * Every relationship the user is part of, as the patient or as the member, newest invitation first. status is
     * optional. The other person's account may be inactive: the row is still shown, so the patient can revoke it.
     */
    @Transactional(readOnly = true)
    public List<CareRelationshipRow> findForUser(long userId, String status) {
        MapSqlParameterSource params = new MapSqlParameterSource("user", userId).addValue("status", status);
        return jdbc.query(SELECT + """
                 WHERE (r.patient_id = :user OR r.member_id = :user)
                   AND (CAST(:status AS varchar) IS NULL OR r.status = :status)
                 ORDER BY r.invited_at DESC, r.id DESC
                """, params, ROW);
    }

    /**
     * A new PENDING invitation; returns its id. A second open invitation for the same pair breaks ux_care_open_pair.
     * expiresAt may be null (no end date).
     */
    @Transactional
    public long insertInvitation(long patientId, long memberId, String memberRole, Permissions permissions,
            long invitedBy, Instant expiresAt) {
        MapSqlParameterSource params = permissionParams(permissions)
                .addValue("patient", patientId)
                .addValue("member", memberId)
                .addValue("role", memberRole)
                .addValue("invitedBy", invitedBy)
                .addValue("expiresAt", timestamp(expiresAt), Types.TIMESTAMP_WITH_TIMEZONE);
        Long id = jdbc.queryForObject("""
                INSERT INTO care_relationships (patient_id, member_id, member_role, status, can_view_glucose,
                       can_view_meals, can_view_medications, can_view_activity, can_view_reports, can_receive_alerts,
                       can_add_recommendations, invited_by, expires_at)
                VALUES (:patient, :member, :role, 'PENDING', :glucose, :meals, :medications, :activity, :reports,
                        :alerts, :recommendations, :invitedBy, :expiresAt)
                RETURNING id
                """, params, Long.class);
        return id;
    }

    /**
     * An ACTIVE relationship in which the caregiver manages a dependent (V12): every view permission, no
     * recommendations, no end date. Returns its id. The database refuses it for a patient who has an account
     * (care_manager_guard) and for a second open manager (ux_care_one_manager).
     */
    @Transactional
    public long insertManaging(long patientId, long caregiverId) {
        MapSqlParameterSource params = permissionParams(MANAGING_PERMISSIONS)
                .addValue("patient", patientId)
                .addValue("member", caregiverId);
        return jdbc.queryForObject("""
                INSERT INTO care_relationships (patient_id, member_id, member_role, status, manages_patient,
                       can_view_glucose, can_view_meals, can_view_medications, can_view_activity, can_view_reports,
                       can_receive_alerts, can_add_recommendations, invited_by)
                VALUES (:patient, :member, 'CAREGIVER', 'ACTIVE', true, :glucose, :meals, :medications, :activity,
                        :reports, :alerts, :recommendations, :member)
                RETURNING id
                """, params, Long.class);
    }

    /** The id of the ACTIVE relationship in which this caregiver manages this patient, if there is one. */
    @Transactional(readOnly = true)
    public Optional<Long> findManagingId(long caregiverId, long patientId) {
        return jdbc.query("""
                SELECT id FROM care_relationships
                WHERE member_id = :member AND patient_id = :patient AND manages_patient AND status = 'ACTIVE'
                """, Map.of("member", caregiverId, "patient", patientId), (rs, i) -> rs.getLong(1))
                .stream().findFirst();
    }

    /** How many dependents this caregiver manages now (ACTIVE). */
    public int countManagedBy(long caregiverId) {
        Integer count = jdbc.queryForObject("""
                SELECT count(*) FROM care_relationships
                WHERE member_id = :member AND manages_patient AND status = 'ACTIVE'
                """, Map.of("member", caregiverId), Integer.class);
        return count == null ? 0 : count;
    }

    /** Locks the caregiver's user row until the end of the transaction, so their dependents are added one by one. */
    public void lockMemberForDependent(long caregiverId) {
        jdbc.query("SELECT id FROM users WHERE id = :member FOR UPDATE", Map.of("member", caregiverId),
                (rs, i) -> rs.getLong(1));
    }

    /** Whether this relationship is one in which a caregiver manages a dependent. */
    @Transactional(readOnly = true)
    public boolean isManaging(long id) {
        Boolean managing = jdbc.queryForObject(
                "SELECT EXISTS (SELECT 1 FROM care_relationships WHERE id = :id AND manages_patient)",
                Map.of("id", id), Boolean.class);
        return Boolean.TRUE.equals(managing);
    }

    /** What a managing caregiver's row says: everything shared except recommendations (fn_can_access grants it all anyway). */
    public static final Permissions MANAGING_PERMISSIONS = new Permissions(true, true, true, true, true, true, false);

    /**
     * Locks the patient's profile row until the end of the transaction (SELECT ... FOR UPDATE), so the invitations of
     * one patient run one after the other: the daily limit is counted and enforced as one step.
     */
    public void lockPatientForInvitation(long patientId) {
        jdbc.query("SELECT user_id FROM patient_profiles WHERE user_id = :patient FOR UPDATE",
                Map.of("patient", patientId), (rs, i) -> rs.getLong(1));
    }

    /**
     * When this patient made their n-th most recent invitation attempt (n = 1 is the latest), or empty if they made
     * fewer. An attempt is a saved invitation (CARE_INVITED) or a refused one (CARE_INVITE_REFUSED) in the audit
     * trail. Used for the daily limit: if the limit-th latest attempt is less than a day old, the limit is reached.
     */
    public Optional<Instant> nthLatestInvitationAttemptAt(long patientId, int n) {
        return jdbc.query("""
                SELECT created_at FROM audit_logs
                WHERE user_id = :patient AND action IN ('CARE_INVITED', 'CARE_INVITE_REFUSED')
                ORDER BY created_at DESC
                LIMIT 1 OFFSET :skip
                """, Map.of("patient", patientId, "skip", n - 1), (rs, i) -> instant(rs, "created_at"))
                .stream().findFirst();
    }

    /** Whether the patient and the member already have a PENDING or ACTIVE relationship. */
    public boolean hasOpenRelationship(long patientId, long memberId) {
        Boolean open = jdbc.queryForObject("""
                SELECT EXISTS (SELECT 1 FROM care_relationships
                               WHERE patient_id = :patient AND member_id = :member AND status IN ('PENDING', 'ACTIVE'))
                """, Map.of("patient", patientId, "member", memberId), Boolean.class);
        return Boolean.TRUE.equals(open);
    }

    /** Whether the member declined an invitation of this patient after the given time. */
    public boolean declinedSince(long patientId, long memberId, Instant since) {
        Boolean declined = jdbc.queryForObject("""
                SELECT EXISTS (SELECT 1 FROM care_relationships
                               WHERE patient_id = :patient AND member_id = :member AND status = 'DECLINED'
                                 AND responded_at > :since)
                """, new MapSqlParameterSource().addValue("patient", patientId).addValue("member", memberId)
                        .addValue("since", timestamp(since), Types.TIMESTAMP_WITH_TIMEZONE), Boolean.class);
        return Boolean.TRUE.equals(declined);
    }

    /** PENDING -> ACTIVE, only by the invited member. Returns the number of rows changed (0 or 1). */
    @Transactional
    public int acceptIfPending(long id, long memberId) {
        return jdbc.update("""
                UPDATE care_relationships SET status = 'ACTIVE'
                WHERE id = :id AND member_id = :member AND status = 'PENDING'
                """, Map.of("id", id, "member", memberId));
    }

    /** PENDING -> DECLINED, only by the invited member. */
    @Transactional
    public int declineIfPending(long id, long memberId) {
        return jdbc.update("""
                UPDATE care_relationships SET status = 'DECLINED'
                WHERE id = :id AND member_id = :member AND status = 'PENDING'
                """, Map.of("id", id, "member", memberId));
    }

    /** PENDING or ACTIVE -> REVOKED (the patient withdraws or cancels, or the member leaves). */
    @Transactional
    public int revokeIfOpen(long id) {
        return jdbc.update("""
                UPDATE care_relationships SET status = 'REVOKED'
                WHERE id = :id AND status IN ('PENDING', 'ACTIVE')
                """, Map.of("id", id));
    }

    /** New permission flags and end date (null = none) of a PENDING or ACTIVE relationship of this patient. */
    @Transactional
    public int updatePermissionsIfOpen(long id, long patientId, Permissions permissions, Instant expiresAt) {
        return jdbc.update("""
                UPDATE care_relationships
                SET can_view_glucose = :glucose, can_view_meals = :meals, can_view_medications = :medications,
                    can_view_activity = :activity, can_view_reports = :reports, can_receive_alerts = :alerts,
                    can_add_recommendations = :recommendations, expires_at = :expiresAt
                WHERE id = :id AND patient_id = :patient AND status IN ('PENDING', 'ACTIVE')
                """, permissionParams(permissions).addValue("id", id).addValue("patient", patientId)
                .addValue("expiresAt", timestamp(expiresAt), Types.TIMESTAMP_WITH_TIMEZONE));
    }

    private static MapSqlParameterSource permissionParams(Permissions permissions) {
        return new MapSqlParameterSource()
                .addValue("glucose", permissions.viewGlucose())
                .addValue("meals", permissions.viewMeals())
                .addValue("medications", permissions.viewMedications())
                .addValue("activity", permissions.viewActivity())
                .addValue("reports", permissions.viewReports())
                .addValue("alerts", permissions.receiveAlerts())
                .addValue("recommendations", permissions.addRecommendations());
    }

    private static CareRelationshipRow row(ResultSet rs, int i) throws SQLException {
        long invitedById = rs.getLong("invited_by");
        Long invitedBy = rs.wasNull() ? null : invitedById; // wasNull() must follow its own getLong() at once
        return new CareRelationshipRow(
                rs.getLong("id"),
                rs.getLong("patient_id"),
                rs.getString("patient_first_name"),
                rs.getString("patient_last_name"),
                rs.getLong("member_id"),
                rs.getString("member_first_name"),
                rs.getString("member_last_name"),
                rs.getString("member_email"),
                rs.getString("member_role"),
                rs.getString("status"),
                new Permissions(
                        rs.getBoolean("can_view_glucose"),
                        rs.getBoolean("can_view_meals"),
                        rs.getBoolean("can_view_medications"),
                        rs.getBoolean("can_view_activity"),
                        rs.getBoolean("can_view_reports"),
                        rs.getBoolean("can_receive_alerts"),
                        rs.getBoolean("can_add_recommendations")),
                invitedBy,
                instant(rs, "invited_at"),
                instant(rs, "responded_at"),
                instant(rs, "revoked_at"),
                instant(rs, "expires_at"));
    }

    private static OffsetDateTime timestamp(Instant value) {
        return value == null ? null : value.atOffset(ZoneOffset.UTC);
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        Timestamp value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    /** The seven can_* columns, in table order. */
    public record Permissions(boolean viewGlucose, boolean viewMeals, boolean viewMedications, boolean viewActivity,
            boolean viewReports, boolean receiveAlerts, boolean addRecommendations) {
    }

    public record CareRelationshipRow(long id, long patientId, String patientFirstName, String patientLastName,
            long memberId, String memberFirstName, String memberLastName, String memberEmail, String memberRole,
            String status, Permissions permissions, Long invitedBy, Instant invitedAt, Instant respondedAt,
            Instant revokedAt, Instant expiresAt) {
    }
}

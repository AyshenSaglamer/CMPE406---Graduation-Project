package com.diamate.backend.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Who may see which patient, and the data shown to them. Uses plain SQL (not JPA) because it reads a
 * database function (fn_can_access) and a view (v_patient_overview), which are not entities.
 * The access rule lives in ONE place, the database function, as recommended in Database/docs/BACKEND_NOTES.md.
 */
@Repository
public class PatientAccessRepository {

    /** Permission names understood by fn_can_access (one per care_relationships.can_view_* flag). */
    public static final String PERMISSION_GLUCOSE = "glucose";
    public static final String PERMISSION_MEALS = "meals";
    // There is no separate insulin flag: insulin doses are shared under "medications".
    public static final String PERMISSION_MEDICATIONS = "medications";
    public static final String PERMISSION_ACTIVITY = "activity";

    private final NamedParameterJdbcTemplate jdbc;

    public PatientAccessRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * True if the viewer is the patient, or has an ACTIVE, not expired care relationship with the patient
     * that grants this permission. ADMIN has no implicit access (by design).
     */
    public boolean canAccess(long viewerId, long patientId, String permission) {
        Boolean allowed = jdbc.queryForObject(
                "SELECT fn_can_access(:viewer, :patient, :permission)",
                new MapSqlParameterSource()
                        .addValue("viewer", viewerId)
                        .addValue("patient", patientId)
                        .addValue("permission", permission),
                Boolean.class);
        return Boolean.TRUE.equals(allowed);
    }

    public Optional<PatientOverviewRow> findOverview(long patientId) {
        List<PatientOverviewRow> rows = jdbc.query("""
                SELECT patient_id, first_name, last_name, gender, age_years, diabetes_type, therapy_type,
                       target_min_mgdl, target_max_mgdl, last_glucose_mgdl, last_glucose_at, open_alerts
                FROM v_patient_overview
                WHERE patient_id = :patient
                """,
                Map.of("patient", patientId),
                (rs, i) -> new PatientOverviewRow(
                        rs.getLong("patient_id"),
                        rs.getString("first_name"),
                        rs.getString("last_name"),
                        rs.getString("gender"),
                        nullableInt(rs, "age_years"),
                        rs.getString("diabetes_type"),
                        rs.getString("therapy_type"),
                        rs.getInt("target_min_mgdl"),
                        rs.getInt("target_max_mgdl"),
                        nullableInt(rs, "last_glucose_mgdl"),
                        instant(rs, "last_glucose_at"),
                        rs.getLong("open_alerts")));
        return rows.stream().findFirst();
    }

    /** Patients the member (clinician or caregiver) currently has an ACTIVE, not expired relationship with. */
    public List<CareTeamPatientRow> findActivePatientsOf(long memberId) {
        return jdbc.query("""
                SELECT u.id AS patient_id, u.first_name, u.last_name,
                       r.can_view_glucose, r.can_view_meals, r.can_view_medications, r.can_view_activity,
                       r.can_view_reports, r.can_receive_alerts, r.can_add_recommendations
                FROM care_relationships r
                JOIN users u ON u.id = r.patient_id
                WHERE r.member_id = :member
                  AND r.status = 'ACTIVE'
                  AND (r.expires_at IS NULL OR r.expires_at > now())
                  AND u.is_active
                ORDER BY u.last_name, u.first_name, u.id
                """,
                Map.of("member", memberId),
                (rs, i) -> new CareTeamPatientRow(
                        rs.getLong("patient_id"),
                        rs.getString("first_name"),
                        rs.getString("last_name"),
                        rs.getBoolean("can_view_glucose"),
                        rs.getBoolean("can_view_meals"),
                        rs.getBoolean("can_view_medications"),
                        rs.getBoolean("can_view_activity"),
                        rs.getBoolean("can_view_reports"),
                        rs.getBoolean("can_receive_alerts"),
                        rs.getBoolean("can_add_recommendations")));
    }

    private static Integer nullableInt(ResultSet rs, String column) throws SQLException {
        int value = rs.getInt(column);
        return rs.wasNull() ? null : value;
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        Timestamp value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    public record PatientOverviewRow(long patientId, String firstName, String lastName, String gender,
            Integer ageYears, String diabetesType, String therapyType, int targetMinMgdl, int targetMaxMgdl,
            Integer lastGlucoseMgdl, Instant lastGlucoseAt, long openAlerts) {
    }

    public record CareTeamPatientRow(long patientId, String firstName, String lastName,
            boolean canViewGlucose, boolean canViewMeals, boolean canViewMedications, boolean canViewActivity,
            boolean canViewReports, boolean canReceiveAlerts, boolean canAddRecommendations) {
    }
}

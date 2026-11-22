-- V8: a care team member no longer sees the data of a patient whose account is inactive.
--
-- fn_can_access checked that the MEMBER's account is active, but not the PATIENT's. When an ADMIN stopped a patient
-- account (compromised, abused, or closed on request), the patient disappeared from the member's care-team list
-- (PatientAccessRepository.findActivePatientsOf filters on it), yet the member could still read every shared record by
-- calling the patient's id directly (week 3 security review, OWASP A01). Both now follow the same rule.
--
-- Only the function body changes (CREATE OR REPLACE keeps its owner and grants); no rows change. The patient's own
-- access (p_viewer = p_patient) stays as it was: an inactive account cannot log in and its tokens are rejected anyway.

CREATE OR REPLACE FUNCTION fn_can_access(p_viewer bigint, p_patient bigint, p_permission text DEFAULT 'glucose')
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT p_viewer = p_patient
        OR EXISTS (
            SELECT 1
            FROM care_relationships r
            JOIN users m ON m.id = r.member_id AND m.is_active
            JOIN users p ON p.id = r.patient_id AND p.is_active
            WHERE r.patient_id = p_patient
              AND r.member_id  = p_viewer
              AND r.status = 'ACTIVE'
              AND (r.expires_at IS NULL OR r.expires_at > now())
              AND CASE lower(p_permission)
                      WHEN 'glucose'     THEN r.can_view_glucose
                      WHEN 'meals'       THEN r.can_view_meals
                      WHEN 'medications' THEN r.can_view_medications
                      WHEN 'activity'    THEN r.can_view_activity
                      WHEN 'reports'     THEN r.can_view_reports
                      WHEN 'alerts'      THEN r.can_receive_alerts
                      WHEN 'recommend'   THEN r.can_add_recommendations
                      ELSE false
                  END
        )
$$;

COMMENT ON FUNCTION fn_can_access IS 'Authorisation helper: patient itself, or clinician/caregiver with an ACTIVE, not expired care relationship that grants the permission, both accounts active.';

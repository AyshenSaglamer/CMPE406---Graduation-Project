-- V5: every CLINICIAN user gets a clinician_profiles row (the clinician counterpart of V4).
--
-- treatment_plans, medications (prescribed_by) and recommendations reference clinician_profiles, and
-- Database/sql/11_verify.sql reports a clinician without this row as an error. Registration creates the row from
-- now on (AuthService); this adds it for clinicians who registered before that. specialization, hospital_name and
-- license_number keep their column defaults ('General', empty) until a profile endpoint exists.
-- Only inserts missing rows: existing profiles (e.g. the demo clinicians) are not touched.

INSERT INTO clinician_profiles (user_id)
SELECT u.id
FROM users u
WHERE u.role = 'CLINICIAN'
  AND NOT EXISTS (SELECT 1 FROM clinician_profiles c WHERE c.user_id = u.id);

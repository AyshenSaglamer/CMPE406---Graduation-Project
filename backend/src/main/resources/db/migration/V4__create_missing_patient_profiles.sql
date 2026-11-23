-- V4: every PATIENT user gets a patient_profiles row.
--
-- All patient log tables (glucose_logs, insulin_logs, meal_logs, activity_logs, ...) reference patient_profiles,
-- so a patient without this row cannot save any data. Registration creates the row from now on (AuthService);
-- this adds it for patients who registered before that. diabetes_type is required but not asked at registration,
-- so it starts as OTHER; targets and alert thresholds keep their column defaults (70/180, 54/250).
-- Only inserts missing rows: existing profiles (e.g. the demo patients) are not touched.

INSERT INTO patient_profiles (user_id, diabetes_type)
SELECT u.id, 'OTHER'
FROM users u
WHERE u.role = 'PATIENT'
  AND NOT EXISTS (SELECT 1 FROM patient_profiles p WHERE p.user_id = u.id);

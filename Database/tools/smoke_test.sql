-- DiaMate: smoke test for roles, cascades and view plans. Everything runs inside transactions that are rolled back (nothing is changed).
-- psql -d diamate -f tools/smoke_test.sql   (expected errors: audit_logs UPDATE for diamate_app, users.password_hash for diamate_readonly)
\set ON_ERROR_STOP off
\echo --- delete demo users (rolled back)
BEGIN;
SELECT count(*) AS users_before FROM users;
DELETE FROM users WHERE is_demo;
SELECT (SELECT count(*) FROM users) users_after, (SELECT count(*) FROM glucose_logs) glucose_after, (SELECT count(*) FROM care_relationships) care_after,
       (SELECT count(*) FROM audit_logs) audit_after, (SELECT count(*) FROM audit_logs WHERE user_id IS NULL) audit_detached,
       (SELECT count(*) FROM research.patients) research_intact;
ROLLBACK;
\echo --- password change statement (rolled back)
BEGIN;
UPDATE users SET password_hash = crypt('NewPass!1', gen_salt('bf', 10)) WHERE is_demo;
SELECT bool_and(password_hash = crypt('NewPass!1', password_hash)) AS new_pw_ok, min(left(password_hash, 7)) AS prefix FROM users WHERE is_demo;
ROLLBACK;
\echo --- diamate_app
BEGIN; SET LOCAL ROLE diamate_app;
SELECT count(*) AS app_can_read_users FROM users;
SELECT count(*) AS app_can_read_research FROM research.patients;
INSERT INTO glucose_logs (patient_id, glucose_value, measurement_time) SELECT user_id, 111, now() FROM patient_profiles LIMIT 1;
UPDATE audit_logs SET action = 'X' WHERE false;
DELETE FROM audit_logs WHERE id = -1;
INSERT INTO research.patients (patient_id, source, diabetes_type, time_basis, n_records) VALUES ('X','X','X','real',1);
ROLLBACK;
\echo --- diamate_readonly
BEGIN; SET LOCAL ROLE diamate_readonly;
SELECT count(*) AS ro_can_read_glucose FROM glucose_logs;
SELECT id, role, full_name FROM users LIMIT 1;
SELECT password_hash FROM users LIMIT 1;
INSERT INTO glucose_logs (patient_id, glucose_value, measurement_time) SELECT user_id, 111, now() FROM patient_profiles LIMIT 1;
ROLLBACK;
\echo --- fn_can_access sample / view speed
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON) SELECT * FROM v_glucose_daily WHERE patient_id = (SELECT id FROM users WHERE email='patient01@diamate.example') AND day > current_date - 14;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON) SELECT * FROM v_latest_glucose WHERE patient_id = (SELECT id FROM users WHERE email='patient01@diamate.example');
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON) SELECT * FROM v_logbook WHERE patient_id = (SELECT id FROM users WHERE email='patient01@diamate.example') AND event_time > now() - interval '2 days' ORDER BY event_time DESC LIMIT 50;

-- =====================================================================================================================
-- DiaMate: demo accounts and demo data.   Safe to skip: the application works without it.
--
--   * 1 admin, 2 clinicians, 1 caregiver, 8 patients (every account has is_demo = true)
--   * 8 patients are linked to real, anonymised patients of the open datasets (research schema); their last 90 days of data
--     are copied into the application tables and shifted in time so that the newest reading is "today"
--   * care relationships (ACTIVE / PENDING / REVOKED), treatment plans, medications, reminders + 7 days of reminder events,
--     alerts + notifications, recommendations, one AI assistant conversation, lab results, sample report, audit entries
--
-- Password of ALL demo accounts:  DiaMate!2026   (override:  psql -v demo_password='something' ...)
-- Passwords are stored as bcrypt ($2a$10$...), the format Spring Security's BCryptPasswordEncoder reads.
-- Demographics (sex, age, height, weight, diabetes duration) that the source datasets do not contain (HUPA-UCM, UC_HT) are
-- SYNTHETIC values chosen for the demo.
-- =====================================================================================================================
\set ON_ERROR_STOP on
\if :{?demo_password}
\else
\set demo_password 'DiaMate!2026'
\endif

BEGIN;

-- ------------------------------------------------------------------------------------------------------------ users
INSERT INTO users (email, password_hash, role, full_name, phone, is_demo, email_verified) VALUES
    ('admin@diamate.example',         crypt(:'demo_password', gen_salt('bf', 10)), 'ADMIN',     'DiaMate Admin',              NULL, true, true),
    ('dr.endo@diamate.example',       crypt(:'demo_password', gen_salt('bf', 10)), 'CLINICIAN', 'Dr. Demo Endocrinologist',   '+357 00 000001', true, true),
    ('dr.diabetes@diamate.example',   crypt(:'demo_password', gen_salt('bf', 10)), 'CLINICIAN', 'Dr. Demo Diabetologist',     '+357 00 000002', true, true),
    ('caregiver@diamate.example',     crypt(:'demo_password', gen_salt('bf', 10)), 'CAREGIVER', 'Demo Caregiver',             '+357 00 000003', true, true);

CREATE TEMP TABLE demo_patients (
    idx int PRIMARY KEY, email text, full_name text, research_id text, therapy text, dtype text,
    synth_sex text, synth_age int, synth_height_cm numeric, synth_weight_kg numeric, synth_duration_y int, tz text
) ON COMMIT DROP;
INSERT INTO demo_patients VALUES
    (1, 'patient01@diamate.example', 'Demo Patient 01', 'HU_0027',    'PUMP', 'TYPE_1', 'MALE',   34, 178, 76, 15, 'UTC'),
    (2, 'patient02@diamate.example', 'Demo Patient 02', 'HU_0026',    'PUMP', 'TYPE_1', 'FEMALE', 41, 165, 64, 20, 'UTC'),
    (3, 'patient03@diamate.example', 'Demo Patient 03', 'HU_0003',    'PUMP', 'TYPE_1', 'MALE',   28, 180, 82,  9, 'UTC'),
    (4, 'patient04@diamate.example', 'Demo Patient 04', 'HU_0007',    'PUMP', 'TYPE_1', 'FEMALE', 52, 160, 70, 25, 'UTC'),
    (5, 'patient05@diamate.example', 'Demo Patient 05', 'UC_T1DM_03', 'PUMP', 'TYPE_1', 'MALE',   45, 175, 80, 12, 'UTC'),
    (6, 'patient06@diamate.example', 'Demo Patient 06', 'SH1_1006',   'MDI',  'TYPE_1', NULL, NULL, NULL, NULL, NULL, 'UTC'),
    (7, 'patient07@diamate.example', 'Demo Patient 07', 'SH2_2017',   'MIXED','TYPE_2', NULL, NULL, NULL, NULL, NULL, 'UTC'),
    (8, 'patient08@diamate.example', 'Demo Patient 08', 'SH2_2069',   'MIXED','TYPE_2', NULL, NULL, NULL, NULL, NULL, 'UTC');

INSERT INTO users (email, password_hash, role, full_name, is_demo, email_verified)
SELECT email, crypt(:'demo_password', gen_salt('bf', 10)), 'PATIENT', full_name, true, true FROM demo_patients ORDER BY idx;

-- clinician / caregiver profiles and settings
INSERT INTO clinician_profiles (user_id, specialization, hospital_name, license_number)
SELECT id, CASE email WHEN 'dr.endo@diamate.example' THEN 'Endocrinology' ELSE 'Diabetology' END, 'DiaMate Demo Clinic',
       CASE email WHEN 'dr.endo@diamate.example' THEN 'DEMO-0001' ELSE 'DEMO-0002' END
FROM users WHERE role = 'CLINICIAN';

-- patient profiles: demographics from the dataset records when they exist, otherwise the synthetic demo values
INSERT INTO patient_profiles (user_id, diabetes_type, date_of_birth, sex, height_cm, weight_kg, diagnosis_year, therapy_type,
                              target_min_mgdl, target_max_mgdl, hypo_threshold_mgdl, hyper_threshold_mgdl, urgent_low_mgdl, urgent_high_mgdl,
                              emergency_contact_name, emergency_contact_phone, research_patient_id)
SELECT u.id, d.dtype,
       make_date(extract(year FROM now())::int - COALESCE(rp.age_years::int, d.synth_age), 7, 1),
       COALESCE(CASE rp.sex WHEN 'F' THEN 'FEMALE' WHEN 'M' THEN 'MALE' END, d.synth_sex),
       COALESCE(round(rec.height_m::numeric * 100, 1), d.synth_height_cm),
       COALESCE(round(rec.weight_kg::numeric, 1), d.synth_weight_kg),
       extract(year FROM now())::int - COALESCE(round(rec.duration_y)::int, d.synth_duration_y),
       d.therapy,
       CASE WHEN d.idx = 8 THEN 90  ELSE 70  END,     -- patient 08 (85 years): relaxed targets, shows per-patient thresholds
       CASE WHEN d.idx = 8 THEN 200 ELSE 180 END,
       CASE WHEN d.idx = 8 THEN 80  ELSE 70  END,
       CASE WHEN d.idx = 8 THEN 200 ELSE 180 END,
       CASE WHEN d.idx = 8 THEN 60  ELSE 54  END,
       CASE WHEN d.idx = 8 THEN 300 ELSE 250 END,
       'Demo Emergency Contact', '+357 00 000099', d.research_id
FROM demo_patients d
JOIN users u ON u.email = d.email
LEFT JOIN research.patients rp ON rp.patient_id = d.research_id
LEFT JOIN LATERAL (
    SELECT (array_agg(r.height_m ORDER BY r.record_id DESC) FILTER (WHERE r.height_m IS NOT NULL))[1] AS height_m,
           (array_agg(r.weight_kg ORDER BY r.record_id DESC) FILTER (WHERE r.weight_kg IS NOT NULL))[1] AS weight_kg,
           (array_agg(r.diabetes_duration_years ORDER BY r.record_id DESC) FILTER (WHERE r.diabetes_duration_years IS NOT NULL))[1] AS duration_y
    FROM research.records r WHERE r.patient_id = d.research_id) rec ON true;

INSERT INTO user_settings (user_id, language, glucose_unit, timezone, email_reports_enabled)
SELECT u.id, 'en', 'MG_DL',
       COALESCE((SELECT d.tz FROM demo_patients d WHERE d.email = u.email), 'Europe/Nicosia'),
       u.role IN ('CLINICIAN')
FROM users u;

-- ---------------------------------------------------------------------------------------- care team / sharing
INSERT INTO care_relationships (patient_id, member_id, member_role, status, can_view_meals, can_view_reports, can_receive_alerts,
                                can_add_recommendations, invited_by)
SELECT p.id, m.id, m.role, v.status, v.meals, v.reports, v.alerts, m.role = 'CLINICIAN', p.id
FROM (VALUES
    ('patient01@diamate.example', 'dr.endo@diamate.example',     'ACTIVE',  true, true,  true),
    ('patient02@diamate.example', 'dr.endo@diamate.example',     'ACTIVE',  true, true,  true),
    ('patient03@diamate.example', 'dr.endo@diamate.example',     'ACTIVE',  true, true,  true),
    ('patient06@diamate.example', 'dr.endo@diamate.example',     'ACTIVE',  true, true,  true),
    ('patient07@diamate.example', 'dr.endo@diamate.example',     'ACTIVE',  true, true,  true),
    ('patient04@diamate.example', 'dr.diabetes@diamate.example', 'ACTIVE',  true, true,  true),
    ('patient05@diamate.example', 'dr.diabetes@diamate.example', 'ACTIVE',  true, true,  true),
    ('patient08@diamate.example', 'dr.diabetes@diamate.example', 'ACTIVE',  true, true,  true),
    ('patient01@diamate.example', 'dr.diabetes@diamate.example', 'PENDING', true, true,  true),   -- invitation waiting for the patient
    ('patient06@diamate.example', 'dr.diabetes@diamate.example', 'REVOKED', true, true,  true),   -- patient withdrew consent
    ('patient07@diamate.example', 'caregiver@diamate.example',   'ACTIVE',  true, false, true),   -- caregiver: no reports
    ('patient08@diamate.example', 'caregiver@diamate.example',   'ACTIVE',  false, false, true)   -- caregiver: alerts only + glucose
) AS v(patient_email, member_email, status, meals, reports, alerts)
JOIN users p ON p.email = v.patient_email
JOIN users m ON m.email = v.member_email;

INSERT INTO treatment_plans (patient_id, clinician_id, target_glucose_min, target_glucose_max, prescribed_insulin, notes, start_date)
SELECT p.user_id, cr.member_id, p.target_min_mgdl, p.target_max_mgdl,
       CASE p.therapy_type WHEN 'PUMP' THEN 'Rapid-acting insulin by pump (CSII); basal profile managed by the clinic'
                           WHEN 'MDI'  THEN 'Basal insulin once daily plus rapid/short-acting insulin with meals'
                           ELSE 'Basal insulin plus oral agents as listed under medications' END,
       'Demo treatment plan. Review at the next visit.', current_date - 60
FROM patient_profiles p
JOIN care_relationships cr ON cr.patient_id = p.user_id AND cr.member_role = 'CLINICIAN' AND cr.status = 'ACTIVE';

-- ------------------------------------------------------------------------------ import the data of the 8 research patients
CREATE TEMP TABLE demo_import_log (research_id text, result jsonb) ON COMMIT DROP;
INSERT INTO demo_import_log
SELECT d.research_id, demo_import_research_patient(u.id, d.research_id, 90, true)
FROM demo_patients d JOIN users u ON u.email = d.email ORDER BY d.idx;

-- ------------------------------------------------------------------------------------------------------- medications
-- insulin products that appear in the imported doses (names cleaned: text before the first comma, initcap)
INSERT INTO medications (patient_id, name, medication_type, dosage, frequency_text, start_date, is_active)
SELECT DISTINCT ON (patient_id, lower(nm)) patient_id, nm, 'INSULIN', NULL, 'As prescribed', current_date - 90, true
FROM (SELECT patient_id, initcap(trim(split_part(product_name, ',', 1))) AS nm
      FROM insulin_logs WHERE product_name IS NOT NULL AND product_name <> 'Pump bolus') x
WHERE nm <> ''
ORDER BY patient_id, lower(nm);

INSERT INTO medications (patient_id, name, medication_type, dosage, frequency_text, start_date, is_active)
SELECT DISTINCT patient_id, 'Rapid-acting insulin (pump)', 'INSULIN', 'Pump bolus + basal', 'Continuous (CSII)', current_date - 90, true
FROM insulin_logs WHERE delivery_method = 'PUMP_BOLUS';

INSERT INTO medications (patient_id, name, medication_type, dosage, frequency_text, start_date, is_active)
SELECT patient_id, medication_name, 'ORAL', mode() WITHIN GROUP (ORDER BY dose_text), 'As prescribed', current_date - 90, true
FROM medication_intakes GROUP BY patient_id, medication_name;

UPDATE medication_intakes mi SET medication_id = m.id
FROM medications m
WHERE m.patient_id = mi.patient_id AND lower(m.name) = lower(mi.medication_name) AND m.medication_type = 'ORAL';

UPDATE medications m SET prescribed_by = cr.member_id
FROM care_relationships cr
WHERE cr.patient_id = m.patient_id AND cr.member_role = 'CLINICIAN' AND cr.status = 'ACTIVE';

-- ------------------------------------------------------------------------------------------------------ reminders
INSERT INTO reminders (patient_id, reminder_type, message, scheduled_time, timezone)
SELECT p.user_id, 'GLUCOSE_CHECK', 'Check your fasting glucose', time '07:30', 'UTC' FROM patient_profiles p
UNION ALL
SELECT p.user_id, 'GLUCOSE_CHECK', 'Bedtime glucose check', time '22:00', 'UTC' FROM patient_profiles p;

INSERT INTO reminders (patient_id, medication_id, reminder_type, medication_name, dosage, message, scheduled_time, timezone)
SELECT m.patient_id, m.id, 'MEDICATION', m.name, m.dosage, 'Time to take ' || m.name,
       CASE WHEN m.name ~* 'degludec|detemir|glargine' THEN time '21:00' ELSE time '08:00' END, 'UTC'
FROM medications m
WHERE m.is_active AND m.name <> 'Rapid-acting insulin (pump)';

-- one week of reminder occurrences: ~85 % taken, the rest missed (deterministic, no random())
INSERT INTO reminder_events (reminder_id, patient_id, scheduled_for, status, sent_at, acknowledged_at)
SELECT r.id, r.patient_id, s.ts,
       CASE WHEN s.ts > now() THEN 'PENDING'
            WHEN mod(abs(hashtext(r.id::text || s.ts::text)), 100) < 85 THEN 'TAKEN' ELSE 'MISSED' END,
       CASE WHEN s.ts <= now() THEN s.ts END,
       CASE WHEN s.ts <= now() AND mod(abs(hashtext(r.id::text || s.ts::text)), 100) < 85 THEN s.ts + interval '4 minutes' END
FROM reminders r
CROSS JOIN LATERAL (SELECT ((d::date + r.scheduled_time) AT TIME ZONE r.timezone) AS ts
                    FROM generate_series(current_date - 6, current_date, interval '1 day') d) s;

UPDATE reminders r SET
    missed_count      = (SELECT count(*) FROM reminder_events e WHERE e.reminder_id = r.id AND e.status = 'MISSED'),
    last_triggered_at = (SELECT max(e.scheduled_for) FROM reminder_events e WHERE e.reminder_id = r.id AND e.scheduled_for <= now());

-- ---------------------------------------------------------------------------------------------- alerts + notifications
-- one alert per patient / type / 3-hour bucket: URGENT_* and LOW for 7 days, HIGH only for the last 2 days
INSERT INTO alerts (patient_id, alert_type, severity, glucose_log_id, value_mgdl, message, triggered_at, status, resolved_at, follow_up_due_at)
SELECT patient_id, alert_type,
       CASE WHEN alert_type LIKE 'URGENT%' THEN 'CRITICAL' ELSE 'WARNING' END,
       id, glucose_value,
       format('Glucose %s mg/dL is %s (%s).', glucose_value,
              CASE WHEN alert_type IN ('URGENT_LOW', 'LOW') THEN 'below' ELSE 'above' END,
              CASE alert_type WHEN 'URGENT_LOW' THEN 'urgent low' WHEN 'LOW' THEN 'low' WHEN 'HIGH' THEN 'high' ELSE 'urgent high' END),
       measurement_time,
       CASE WHEN measurement_time > now() - interval '24 hours' THEN 'OPEN' ELSE 'RESOLVED' END,
       CASE WHEN measurement_time <= now() - interval '24 hours' THEN measurement_time + interval '45 minutes' END,
       CASE WHEN measurement_time > now() - interval '24 hours' THEN measurement_time + interval '30 minutes' END
FROM (
    SELECT DISTINCT ON (g.patient_id, t.alert_type, floor(extract(epoch FROM g.measurement_time) / 10800))
           g.id, g.patient_id, g.glucose_value, g.measurement_time, t.alert_type
    FROM glucose_logs g
    CROSS JOIN LATERAL (SELECT fn_glucose_alert_type(g.patient_id, g.glucose_value) AS alert_type) t
    WHERE g.measurement_time > now() - interval '7 days' AND t.alert_type IS NOT NULL
      AND (t.alert_type <> 'HIGH' OR g.measurement_time > now() - interval '2 days')
    ORDER BY g.patient_id, t.alert_type, floor(extract(epoch FROM g.measurement_time) / 10800), g.measurement_time
) a;

-- patient gets an in-app notification for every alert of the last 3 days; care team members that may receive alerts get CRITICAL ones
INSERT INTO notifications (recipient_id, alert_id, notification_type, title, body, channel, status, created_at, sent_at, read_at)
SELECT a.patient_id, a.id, 'ALERT', initcap(replace(a.alert_type, '_', ' ')) || ' glucose alert', a.message, 'IN_APP', 'SENT',
       a.triggered_at, a.triggered_at, CASE WHEN a.status = 'RESOLVED' THEN a.triggered_at + interval '10 minutes' END
FROM alerts a WHERE a.triggered_at > now() - interval '3 days';

INSERT INTO notifications (recipient_id, alert_id, notification_type, title, body, channel, status, created_at, sent_at)
SELECT cr.member_id, a.id, 'ALERT', 'Patient alert: ' || u.full_name, a.message, 'IN_APP', 'SENT', a.triggered_at, a.triggered_at
FROM alerts a
JOIN users u ON u.id = a.patient_id
JOIN care_relationships cr ON cr.patient_id = a.patient_id AND cr.status = 'ACTIVE' AND cr.can_receive_alerts
WHERE a.severity = 'CRITICAL' AND a.triggered_at > now() - interval '3 days';

-- ------------------------------------------------------------------------------------------ recommendations (advisory)
INSERT INTO recommendations (patient_id, clinician_id, message, created_at, read_at)
SELECT p.id, c.id, v.msg, now() - v.ago, CASE WHEN v.is_read THEN now() - v.ago + interval '2 hours' END
FROM (VALUES
    ('patient01@diamate.example', 'dr.endo@diamate.example',
     'Please keep logging your meals with carbohydrate amounts; it helps us review your plan together at the next visit.', interval '2 days', false),
    ('patient02@diamate.example', 'dr.endo@diamate.example',
     'Your time in range this week is worth discussing. Please book a review appointment.', interval '4 days', true),
    ('patient07@diamate.example', 'dr.endo@diamate.example',
     'Remember to take the evening dose at the same time every day. Set the reminder in the app.', interval '1 day', false),
    ('patient08@diamate.example', 'dr.diabetes@diamate.example',
     'Please check your glucose before breakfast on at least three days this week and record it in the app.', interval '3 days', false)
) AS v(patient_email, clinician_email, msg, ago, is_read)
JOIN users p ON p.email = v.patient_email
JOIN users c ON c.email = v.clinician_email;

-- ------------------------------------------------------------------------------------------- lab results (HbA1c etc.)
INSERT INTO lab_results (patient_id, test_type, value, unit, taken_at, source, notes)
SELECT u.id, v.test_type, v.val, v.unit, now() - ((21 + 90 * (rn - 1)) || ' days')::interval, 'LAB_IMPORT', 'from dataset record ' || record_id
FROM (SELECT r.patient_id, r.record_id, row_number() OVER (PARTITION BY r.patient_id ORDER BY r.record_id DESC) AS rn,
             r.hba1c_pct, r.fasting_glucose_mgdl, r.postprandial_2h_glucose_mgdl FROM research.records r) r
JOIN demo_patients d ON d.research_id = r.patient_id
JOIN users u ON u.email = d.email
CROSS JOIN LATERAL (VALUES ('HBA1C', r.hba1c_pct::numeric, '%'),
                           ('FASTING_GLUCOSE', r.fasting_glucose_mgdl::numeric, 'mg/dL'),
                           ('POSTPRANDIAL_GLUCOSE_2H', r.postprandial_2h_glucose_mgdl::numeric, 'mg/dL')) v(test_type, val, unit)
WHERE v.val IS NOT NULL AND v.val > 0 AND rn <= 3;

-- --------------------------------------------------------------------------------- a few manual entries for the demo UI
INSERT INTO activity_logs (patient_id, activity_type, started_at, duration_minutes, intensity, source, notes)
SELECT u.id, v.act, date_trunc('hour', now()) - v.ago, v.mins, v.inten, 'MANUAL', 'demo entry'
FROM (VALUES ('patient01@diamate.example', 'Walking', interval '26 hours', 40, 'LOW'),
             ('patient01@diamate.example', 'Cycling', interval '3 days',   60, 'MODERATE'),
             ('patient05@diamate.example', 'Running', interval '2 days',   30, 'HIGH'),
             ('patient07@diamate.example', 'Walking', interval '5 hours',  30, 'LOW'),
             ('patient08@diamate.example', 'Walking', interval '28 hours', 20, 'LOW')) v(email, act, ago, mins, inten)
JOIN users u ON u.email = v.email;

INSERT INTO symptom_logs (patient_id, symptom_type, severity, occurred_at, notes)
SELECT u.id, v.sym, v.sev, now() - v.ago, 'demo entry'
FROM (VALUES ('patient01@diamate.example', 'SHAKING', 3, interval '30 hours'),
             ('patient06@diamate.example', 'FATIGUE', 2, interval '20 hours'),
             ('patient08@diamate.example', 'THIRST',  2, interval '2 days')) v(email, sym, sev, ago)
JOIN users u ON u.email = v.email;

-- AI assistant: "my glucose is 145 before lunch" -> a glucose log created from the conversation
WITH pat AS (SELECT id FROM users WHERE email = 'patient01@diamate.example'),
     conv AS (INSERT INTO ai_conversations (patient_id, title, channel, started_at, ended_at)
              SELECT id, 'Logging a glucose value', 'TEXT', now() - interval '1 hour', now() - interval '59 minutes' FROM pat RETURNING id, patient_id),
     glu AS (INSERT INTO glucose_logs (patient_id, glucose_value, measurement_time, meal_context, source, notes)
             SELECT patient_id, 145, now() - interval '58 minutes', 'BEFORE_MEAL', 'AI_ASSISTANT', 'logged through the Dia assistant' FROM conv RETURNING id)
INSERT INTO ai_messages (conversation_id, sender, content, intent, extracted_value, created_entity_type, created_entity_id, created_at)
SELECT conv.id, m.sender, m.content, m.intent, m.val, m.ent, CASE WHEN m.ent IS NOT NULL THEN (SELECT id FROM glu) END, now() - m.ago
FROM conv CROSS JOIN (VALUES
    ('USER',      'My glucose is 145 before lunch',                                  'LOG_GLUCOSE', 145::numeric, NULL::text,        interval '60 minutes'),
    ('ASSISTANT', 'Logged 145 mg/dL (before meal). That is inside your target range.', NULL,          NULL::numeric, 'GLUCOSE_LOG', interval '59 minutes')
) AS m(sender, content, intent, val, ent, ago);

-- sample report (metrics of the last 7 days; no PDF file behind it)
INSERT INTO reports (patient_id, requested_by, report_type, format, period_start, period_end, status, summary, generated_at)
SELECT u.id, u.id, 'WEEKLY', 'PDF', now() - interval '7 days', now(), 'READY',
       fn_glucose_summary(u.id, now() - interval '7 days', now()), now()
FROM users u WHERE u.email = 'patient01@diamate.example';

INSERT INTO csv_imports (patient_id, uploaded_by, filename, file_format, rows_total, rows_imported, rows_rejected, status, completed_at)
SELECT u.id, u.id, 'libre_export_demo.csv', 'LIBRE', 1200, 1188, 12, 'COMPLETED', now() - interval '6 days'
FROM users u WHERE u.email = 'patient02@diamate.example';

-- audit trail samples
INSERT INTO audit_logs (user_id, patient_id, action, entity_type, entity_id, ip_address, success, details, created_at)
SELECT u.id, CASE WHEN u.role = 'PATIENT' THEN u.id END, 'LOGIN', 'USER', u.id::text, '127.0.0.1', true, '{"demo": true}'::jsonb, now() - interval '1 hour'
FROM users u WHERE u.is_demo;
INSERT INTO audit_logs (user_id, patient_id, action, entity_type, entity_id, ip_address, success, details, created_at)
SELECT c.id, p.id, 'VIEW_PATIENT_DATA', 'PATIENT', p.id::text, '127.0.0.1', true, '{"screen": "glucose_chart"}'::jsonb, now() - interval '50 minutes'
FROM users c, users p WHERE c.email = 'dr.endo@diamate.example' AND p.email = 'patient01@diamate.example';
INSERT INTO audit_logs (user_id, patient_id, action, entity_type, entity_id, ip_address, success, details, created_at)
SELECT p.id, p.id, 'SHARE_GRANTED', 'CARE_RELATIONSHIP', cr.id::text, '127.0.0.1', true, jsonb_build_object('member', cr.member_id), now() - interval '10 days'
FROM care_relationships cr JOIN users p ON p.id = cr.patient_id WHERE cr.status = 'ACTIVE';

-- import summary
SELECT research_id, result->>'glucose_logs' AS glucose, result->>'meal_logs' AS meals, result->>'insulin_logs' AS insulin,
       result->>'medication_intakes' AS meds, result->>'wearable_samples' AS wearable, result->>'shift_days' AS shift_days
FROM demo_import_log ORDER BY research_id;

COMMIT;
ANALYZE;

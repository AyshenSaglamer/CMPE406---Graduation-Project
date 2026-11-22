-- =====================================================================================================================
-- DiaMate application: helper functions and views (schema "public")
-- Everything here is optional convenience for the Spring Boot backend / reporting; no table depends on it.
-- =====================================================================================================================
\set ON_ERROR_STOP on

-- ----------------------------------------------------------------------------------------------------- access check
-- May `p_viewer` see `p_patient`'s data?  p_permission: glucose | meals | medications | activity | reports | alerts | recommend
-- A patient always sees own data. Access for clinicians / caregivers needs an ACTIVE, non-expired care_relationships row
-- with the matching flag. ADMIN has NO implicit access to health data (privacy by design).
CREATE FUNCTION fn_can_access(p_viewer bigint, p_patient bigint, p_permission text DEFAULT 'glucose')
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT p_viewer = p_patient
        OR EXISTS (
            SELECT 1
            FROM care_relationships r
            JOIN users u ON u.id = r.member_id AND u.is_active
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
COMMENT ON FUNCTION fn_can_access IS 'Authorisation helper: patient itself, or clinician/caregiver with an ACTIVE care relationship that grants the permission.';

-- ----------------------------------------------------------------------------------------------------- alert classify
-- Which alert (if any) does a glucose value trigger for this patient? Uses the thresholds in patient_profiles.
CREATE FUNCTION fn_glucose_alert_type(p_patient bigint, p_value numeric)
RETURNS text LANGUAGE sql STABLE AS $$
    SELECT CASE
             WHEN p_value <= p.urgent_low_mgdl  THEN 'URGENT_LOW'
             WHEN p_value <= p.hypo_threshold_mgdl THEN 'LOW'
             WHEN p_value >= p.urgent_high_mgdl THEN 'URGENT_HIGH'
             WHEN p_value >= p.hyper_threshold_mgdl THEN 'HIGH'
           END
    FROM patient_profiles p WHERE p.user_id = p_patient
$$;
COMMENT ON FUNCTION fn_glucose_alert_type IS 'Returns URGENT_LOW / LOW / HIGH / URGENT_HIGH or NULL for a reading. Alert creation itself is left to the backend.';

-- ------------------------------------------------------------------------------------------------ glucose statistics
-- International-consensus CGM metrics over [p_from, p_to). Time in range uses the patient's own targets
-- (target_min/max_mgdl) and the urgent thresholds for the "very low / very high" bands. GMI = 3.31 + 0.02392 * mean(mg/dL).
CREATE FUNCTION fn_glucose_stats(p_patient bigint, p_from timestamptz, p_to timestamptz)
RETURNS TABLE (n_readings bigint, mean_mgdl numeric, sd_mgdl numeric, cv_pct numeric, gmi_pct numeric,
               min_mgdl integer, max_mgdl integer,
               tir_pct numeric, tbr_pct numeric, tbr_severe_pct numeric, tar_pct numeric, tar_severe_pct numeric)
LANGUAGE sql STABLE AS $$
    SELECT count(*),
           round(avg(g.glucose_value), 1),
           round(stddev_samp(g.glucose_value)::numeric, 1),
           round(100 * stddev_samp(g.glucose_value)::numeric / NULLIF(avg(g.glucose_value), 0), 1),
           round(3.31 + 0.02392 * avg(g.glucose_value), 1),
           min(g.glucose_value), max(g.glucose_value),
           round(100.0 * avg((g.glucose_value BETWEEN p.target_min_mgdl AND p.target_max_mgdl)::int), 1),
           round(100.0 * avg((g.glucose_value <  p.target_min_mgdl)::int), 1),
           round(100.0 * avg((g.glucose_value <  p.urgent_low_mgdl)::int), 1),
           round(100.0 * avg((g.glucose_value >  p.target_max_mgdl)::int), 1),
           round(100.0 * avg((g.glucose_value >  p.urgent_high_mgdl)::int), 1)
    FROM glucose_logs g
    JOIN patient_profiles p ON p.user_id = g.patient_id
    WHERE g.patient_id = p_patient AND g.deleted_at IS NULL
      AND g.measurement_time >= p_from AND g.measurement_time < p_to
$$;
COMMENT ON FUNCTION fn_glucose_stats IS 'Mean, SD, CV, GMI, min/max and time in/below/above range for one patient and period.';

CREATE FUNCTION fn_glucose_summary(p_patient bigint, p_from timestamptz, p_to timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
    SELECT to_jsonb(s) || jsonb_build_object('period_start', p_from, 'period_end', p_to)
    FROM fn_glucose_stats(p_patient, p_from, p_to) s
$$;
COMMENT ON FUNCTION fn_glucose_summary IS 'fn_glucose_stats as jsonb: store it in reports.summary.';

-- ------------------------------------------------------------------------------------------------------------ views
CREATE VIEW v_patient_overview AS
SELECT u.id                         AS patient_id,
       u.email, u.full_name, u.is_active, u.is_demo,
       p.diabetes_type, p.therapy_type, p.sex,
       date_part('year', age(p.date_of_birth))::int AS age_years,
       p.height_cm, p.weight_kg,
       round(p.weight_kg / ((p.height_cm / 100) ^ 2), 1) AS bmi,
       p.target_min_mgdl, p.target_max_mgdl, p.hypo_threshold_mgdl, p.hyper_threshold_mgdl,
       lg.glucose_value             AS last_glucose_mgdl,
       lg.measurement_time          AS last_glucose_at,
       (SELECT count(*) FROM alerts a WHERE a.patient_id = u.id AND a.status = 'OPEN') AS open_alerts
FROM users u
JOIN patient_profiles p ON p.user_id = u.id
LEFT JOIN LATERAL (SELECT g.glucose_value, g.measurement_time
                   FROM glucose_logs g
                   WHERE g.patient_id = u.id AND g.deleted_at IS NULL
                   ORDER BY g.measurement_time DESC LIMIT 1) lg ON true;
COMMENT ON VIEW v_patient_overview IS 'One row per patient: profile, BMI, latest glucose, open alert count (dashboard header).';

CREATE VIEW v_latest_glucose AS
SELECT DISTINCT ON (patient_id) patient_id, id AS glucose_log_id, glucose_value, measurement_time, source
FROM glucose_logs
WHERE deleted_at IS NULL
ORDER BY patient_id, measurement_time DESC;

CREATE VIEW v_glucose_daily AS
SELECT g.patient_id,
       (g.measurement_time AT TIME ZONE COALESCE(s.timezone, 'UTC'))::date AS day,
       count(*)                                   AS n_readings,
       round(avg(g.glucose_value), 1)             AS mean_mgdl,
       min(g.glucose_value)                       AS min_mgdl,
       max(g.glucose_value)                       AS max_mgdl,
       round(stddev_samp(g.glucose_value)::numeric, 1) AS sd_mgdl,
       round(100.0 * avg((g.glucose_value BETWEEN p.target_min_mgdl AND p.target_max_mgdl)::int), 1) AS tir_pct,
       round(100.0 * avg((g.glucose_value <  p.target_min_mgdl)::int), 1) AS tbr_pct,
       round(100.0 * avg((g.glucose_value >  p.target_max_mgdl)::int), 1) AS tar_pct
FROM glucose_logs g
JOIN patient_profiles p ON p.user_id = g.patient_id
LEFT JOIN user_settings s ON s.user_id = g.patient_id
WHERE g.deleted_at IS NULL
GROUP BY g.patient_id, 2;
COMMENT ON VIEW v_glucose_daily IS 'Daily glucose statistics per patient (day in the user''s time zone). Always filter by patient_id.';

CREATE VIEW v_glucose_14d AS
SELECT p.user_id AS patient_id, st.*
FROM patient_profiles p
CROSS JOIN LATERAL fn_glucose_stats(p.user_id, now() - interval '14 days', now()) st;
COMMENT ON VIEW v_glucose_14d IS '14-day CGM metrics (mean, GMI, CV, TIR/TBR/TAR) for every patient. Filter by patient_id to keep it cheap.';

CREATE VIEW v_care_team AS
SELECT r.id AS relationship_id, r.patient_id, pu.full_name AS patient_name,
       r.member_id, mu.full_name AS member_name, mu.email AS member_email, r.member_role, r.status,
       r.can_view_glucose, r.can_view_meals, r.can_view_medications, r.can_view_activity, r.can_view_reports,
       r.can_receive_alerts, r.can_add_recommendations, r.invited_at, r.responded_at, r.expires_at
FROM care_relationships r
JOIN users pu ON pu.id = r.patient_id
JOIN users mu ON mu.id = r.member_id;
COMMENT ON VIEW v_care_team IS 'Sharing list for both directions: a patient''s care team, or a clinician''s / caregiver''s patients.';

CREATE VIEW v_reminder_adherence_30d AS
SELECT e.patient_id,
       count(*) FILTER (WHERE e.status = 'TAKEN')  AS taken,
       count(*) FILTER (WHERE e.status = 'MISSED') AS missed,
       count(*) FILTER (WHERE e.status IN ('TAKEN', 'MISSED')) AS due,
       round(100.0 * count(*) FILTER (WHERE e.status = 'TAKEN')
             / NULLIF(count(*) FILTER (WHERE e.status IN ('TAKEN', 'MISSED')), 0), 1) AS adherence_pct
FROM reminder_events e
WHERE e.scheduled_for >= now() - interval '30 days' AND e.scheduled_for < now()
GROUP BY e.patient_id;
COMMENT ON VIEW v_reminder_adherence_30d IS 'Medication adherence: share of due reminders that were taken in the last 30 days.';

-- Chronological logbook (one screen for glucose + meals + insulin + medicines + activity). Filter by patient_id and time.
CREATE VIEW v_logbook AS
SELECT patient_id, measurement_time AS event_time, 'GLUCOSE'::text AS event_type, id AS ref_id,
       glucose_value || ' mg/dL' AS title, meal_context AS detail, glucose_value::numeric AS value
FROM glucose_logs WHERE deleted_at IS NULL
UNION ALL
SELECT patient_id, eaten_at, 'MEAL', id, meal_type || COALESCE(' - ' || left(description, 60), ''),
       CASE WHEN carbs_g IS NOT NULL THEN carbs_g || ' g carbs' END, carbs_g
FROM meal_logs WHERE deleted_at IS NULL
UNION ALL
SELECT patient_id, administered_at, 'INSULIN', id, dose_units || ' U ' || insulin_type, COALESCE(product_name, delivery_method), dose_units
FROM insulin_logs WHERE deleted_at IS NULL
UNION ALL
SELECT patient_id, taken_at, 'MEDICATION', id, medication_name, COALESCE(dose_text, '') || ' ' || status, NULL
FROM medication_intakes WHERE deleted_at IS NULL
UNION ALL
SELECT patient_id, started_at, 'ACTIVITY', id, activity_type, COALESCE(duration_minutes || ' min', ''), duration_minutes
FROM activity_logs WHERE deleted_at IS NULL
UNION ALL
SELECT patient_id, occurred_at, 'SYMPTOM', id, symptom_type, 'severity ' || severity, severity::numeric
FROM symptom_logs WHERE deleted_at IS NULL;
COMMENT ON VIEW v_logbook IS 'Union of all patient log tables ordered by event_time (ORDER BY is left to the query).';

-- ------------------------------------------------------------------------------------- research -> application import
-- Copies the most recent `p_days` days of a research patient's data into the application tables of an existing patient user.
-- Used by 09_demo_seed.sql. Dates are shifted by whole days so that the last day of data is today (demo data looks live):
--   p_shift => false keeps the original dates.
-- Skipped on purpose: rows flagged in research.glucose_readings.quality_flag, pump basal-rate rows and BrisT1D "total
-- delivered per 5 min" rows (they are rates, not doses). Returns a jsonb with the row counts. Refuses to run on a patient
-- who already has glucose logs.
CREATE FUNCTION demo_import_research_patient(p_user_id bigint, p_research_id text, p_days integer DEFAULT 90, p_shift boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_max     timestamp;
    v_from    timestamp;
    v_off     interval := interval '0';
    v_now     timestamp := (now() AT TIME ZONE 'UTC');
    n_glu bigint; n_meal bigint; n_item bigint; n_ins bigint; n_take bigint; n_wear bigint;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM patient_profiles WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'user % has no patient profile', p_user_id;
    END IF;
    IF EXISTS (SELECT 1 FROM glucose_logs WHERE patient_id = p_user_id) THEN
        RAISE EXCEPTION 'user % already has glucose logs; delete them first', p_user_id;
    END IF;

    SELECT max(t) INTO v_max FROM (
        SELECT max(timestamp) t FROM research.glucose_readings WHERE patient_id = p_research_id
        UNION ALL SELECT max(timestamp) FROM research.meals WHERE patient_id = p_research_id
        UNION ALL SELECT max(timestamp) FROM research.insulin_doses WHERE patient_id = p_research_id) x;
    IF v_max IS NULL THEN RAISE EXCEPTION 'research patient % not found', p_research_id; END IF;
    v_from := v_max - make_interval(days => p_days);
    IF p_shift THEN v_off := make_interval(days => (v_now::date - v_max::date)); END IF;

    -- glucose ------------------------------------------------------------------------------------------------------
    INSERT INTO glucose_logs (patient_id, glucose_value, measurement_time, source, entered_by)
    SELECT p_user_id, round(glucose_mgdl)::int, ((timestamp + v_off) AT TIME ZONE 'UTC'),
           CASE reading_type WHEN 'CGM' THEN 'CGM' ELSE 'METER' END, NULL
    FROM research.glucose_readings
    WHERE patient_id = p_research_id AND quality_flag IS NULL AND timestamp > v_from AND (timestamp + v_off) <= v_now
      AND glucose_mgdl BETWEEN 20 AND 600;
    GET DIAGNOSTICS n_glu = ROW_COUNT;

    -- meals (client_uuid is derived from the research meal_id, which makes the items join below exact) ---------------
    INSERT INTO meal_logs (patient_id, meal_type, eaten_at, description, carbs_g, calories_kcal, source, client_uuid)
    SELECT p_user_id,
           CASE WHEN extract(hour FROM timestamp) BETWEEN 5 AND 10 THEN 'BREAKFAST'
                WHEN extract(hour FROM timestamp) BETWEEN 11 AND 14 THEN 'LUNCH'
                WHEN extract(hour FROM timestamp) BETWEEN 18 AND 21 THEN 'DINNER'
                ELSE 'SNACK' END,
           ((timestamp + v_off) AT TIME ZONE 'UTC'),
           description_en,
           CASE WHEN carbs_g BETWEEN 0 AND 1000 THEN round(carbs_g::numeric, 1) END,
           CASE WHEN kcal BETWEEN 0 AND 10000 THEN round(kcal::numeric, 1) END,
           'IMPORT',
           md5(p_research_id || '/' || meal_id)::uuid
    FROM research.meals
    WHERE patient_id = p_research_id AND timestamp > v_from AND (timestamp + v_off) <= v_now
      AND (carbs_g IS NOT NULL OR description_en IS NOT NULL);
    GET DIAGNOSTICS n_meal = ROW_COUNT;

    INSERT INTO meal_log_items (meal_log_id, food_name, amount_g)
    SELECT ml.id, left(mi.food_name, 150), CASE WHEN mi.unit = 'g' AND mi.amount BETWEEN 0 AND 99999 THEN round(mi.amount::numeric, 1) END
    FROM research.meal_items mi
    JOIN meal_logs ml ON ml.patient_id = p_user_id AND ml.client_uuid = md5(p_research_id || '/' || mi.meal_id)::uuid
    WHERE mi.patient_id = p_research_id;
    GET DIAGNOSTICS n_item = ROW_COUNT;

    -- insulin: boluses and injections only --------------------------------------------------------------------------
    INSERT INTO insulin_logs (patient_id, dose_units, insulin_type, delivery_method, product_name, administered_at, meal_log_id, source)
    SELECT p_user_id, round(i.dose_iu::numeric, 2),
           CASE WHEN i.route = 'pump_CSII' THEN 'RAPID'
                WHEN i.product ~* 'aspart|lispro|glulisine|novorapid|humalog|fiasp' THEN 'RAPID'
                WHEN i.product ~* 'humulin r|gansulin r|regular|actrapid' THEN 'SHORT'
                WHEN i.product ~* 'glargine|detemir|degludec|lantus|levemir|tresiba|toujeo' THEN 'LONG'
                WHEN i.product ~* 'nph|isophane|humulin n|gansulin n' THEN 'INTERMEDIATE'
                WHEN i.product ~* '30r|50r|70/30|mixtard|premix|novomix' THEN 'MIXED'
                ELSE 'OTHER' END,
           CASE WHEN i.route = 'pump_CSII' THEN 'PUMP_BOLUS' ELSE 'OTHER' END,
           CASE WHEN i.route = 'pump_CSII' THEN 'Pump bolus' ELSE left(i.product, 100) END,
           ((i.timestamp + v_off) AT TIME ZONE 'UTC'),
           m.id,
           CASE WHEN i.route = 'pump_CSII' THEN 'PUMP' ELSE 'IMPORT' END
    FROM research.insulin_doses i
    LEFT JOIN LATERAL (SELECT ml.id FROM meal_logs ml
                       WHERE ml.patient_id = p_user_id
                         AND ml.eaten_at BETWEEN ((i.timestamp + v_off) AT TIME ZONE 'UTC') - interval '30 minutes'
                                             AND ((i.timestamp + v_off) AT TIME ZONE 'UTC') + interval '30 minutes'
                       ORDER BY abs(extract(epoch FROM ml.eaten_at - ((i.timestamp + v_off) AT TIME ZONE 'UTC'))) LIMIT 1) m ON true
    WHERE i.patient_id = p_research_id AND i.dose_iu BETWEEN 0.01 AND 300 AND i.timestamp > v_from AND (i.timestamp + v_off) <= v_now
      AND ((i.route = 'pump_CSII' AND i.kind = 'bolus') OR i.route = 'subcutaneous');
    GET DIAGNOSTICS n_ins = ROW_COUNT;

    -- oral medicines: intakes (distinct drugs are turned into the medication list by the seed) -------------------------
    INSERT INTO medication_intakes (patient_id, medication_name, dose_text, taken_at, status)
    SELECT p_user_id, initcap(drug),
           CASE WHEN dose_mg IS NULL THEN NULL
                WHEN drug = 'voglibose' AND dose_mg > 1 THEN NULL          -- values like 400 mg in the source are not plausible
                ELSE trim(trailing '.' FROM trim(trailing '0' FROM round(dose_mg::numeric, 3)::text)) || ' mg' END,
           ((timestamp + v_off) AT TIME ZONE 'UTC'), 'TAKEN'
    FROM research.oral_medications
    WHERE patient_id = p_research_id AND drug IS NOT NULL AND timestamp > v_from AND (timestamp + v_off) <= v_now;
    GET DIAGNOSTICS n_take = ROW_COUNT;

    -- wearable telemetry ---------------------------------------------------------------------------------------------
    INSERT INTO wearable_samples (patient_id, sample_time, heart_rate_bpm, steps, calories_kcal, source)
    SELECT DISTINCT ON (ts) p_user_id, ts, hr, st, kcal, src
    FROM (SELECT ((a.timestamp + v_off) AT TIME ZONE 'UTC') AS ts,
                 CASE WHEN a.heart_rate_bpm BETWEEN 20 AND 260 THEN round(a.heart_rate_bpm)::int END AS hr,
                 CASE WHEN a.steps_5min >= 0 THEN round(a.steps_5min)::int END AS st,
                 CASE WHEN a.calories_kcal >= 0 THEN round(a.calories_kcal::numeric, 3) END AS kcal,
                 'WEARABLE' AS src
          FROM research.activity a
          WHERE a.patient_id = p_research_id AND a.timestamp > v_from AND (a.timestamp + v_off) <= v_now) w
    WHERE hr IS NOT NULL OR st IS NOT NULL OR kcal IS NOT NULL
    ORDER BY ts;
    GET DIAGNOSTICS n_wear = ROW_COUNT;

    RETURN jsonb_build_object('research_patient', p_research_id, 'from', v_from + v_off, 'to', v_max + v_off,
                              'shift_days', extract(day FROM v_off), 'glucose_logs', n_glu, 'meal_logs', n_meal,
                              'meal_log_items', n_item, 'insulin_logs', n_ins, 'medication_intakes', n_take,
                              'wearable_samples', n_wear);
END $$;
COMMENT ON FUNCTION demo_import_research_patient IS 'Demo/dev helper: copies recent research.* data of one open-dataset patient into a patient user''s log tables.';

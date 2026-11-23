-- DiaMate: post-install checks of the application schema. Stops with an error if something is wrong.
-- Needs the psql variable demo_password when the demo seed was installed (run_all.sql sets the default).
\set ON_ERROR_STOP on

\echo
\echo === row counts ===
SELECT table_schema AS schema, table_name AS "table",
       (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text::bigint AS rows
FROM information_schema.tables
WHERE table_schema IN ('public', 'research') AND table_type = 'BASE TABLE'
ORDER BY table_schema DESC, table_name;

\echo
\echo === checks ===
DO $$
DECLARE
    bad text[] := '{}';
    n   bigint;
BEGIN
    -- structure
    SELECT count(*) INTO n FROM users u WHERE u.role = 'PATIENT' AND NOT EXISTS (SELECT 1 FROM patient_profiles p WHERE p.user_id = u.id);
    IF n > 0 THEN bad := bad || format('%s patient users without profile', n); END IF;
    SELECT count(*) INTO n FROM users u WHERE u.role = 'CLINICIAN' AND NOT EXISTS (SELECT 1 FROM clinician_profiles p WHERE p.user_id = u.id);
    IF n > 0 THEN bad := bad || format('%s clinician users without profile', n); END IF;
    SELECT count(*) INTO n FROM information_schema.tables t WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
        AND NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conrelid = format('public.%I', t.table_name)::regclass AND c.contype = 'p');
    IF n > 0 THEN bad := bad || format('%s public tables without primary key', n); END IF;
    SELECT count(*) INTO n FROM food_catalog;
    IF n <> 101 THEN bad := bad || format('food_catalog has %s rows, expected 101', n); END IF;

    -- audit trail must reject changes
    BEGIN
        INSERT INTO audit_logs (action) VALUES ('VERIFY_TEST');
        UPDATE audit_logs SET action = 'TAMPERED' WHERE action = 'VERIFY_TEST';
        bad := bad || 'audit_logs UPDATE was NOT rejected';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO audit_logs (action) VALUES ('VERIFY_TEST');
        DELETE FROM audit_logs WHERE action = 'VERIFY_TEST';
        bad := bad || 'audit_logs DELETE was NOT rejected';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    -- role guard triggers
    BEGIN
        INSERT INTO patient_profiles (user_id, diabetes_type) SELECT id, 'TYPE_1' FROM users WHERE role = 'ADMIN' LIMIT 1;
        IF FOUND THEN bad := bad || 'patient profile for an ADMIN user was accepted'; END IF;
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    IF array_length(bad, 1) IS NOT NULL THEN
        RAISE EXCEPTION E'VERIFY FAILED:\n  - %', array_to_string(bad, E'\n  - ');
    END IF;
    RAISE NOTICE 'structure checks passed';
END $$;

-- demo-specific checks (skipped when no demo accounts exist)
DO $$
DECLARE
    bad text[] := '{}';
    n   bigint;
    p1 bigint; p6 bigint; p7 bigint; p8 bigint; adm bigint; endo bigint; dia bigint; cg bigint;
BEGIN
    SELECT count(*) INTO n FROM users WHERE is_demo;
    IF n = 0 THEN RAISE NOTICE 'no demo accounts installed, demo checks skipped'; RETURN; END IF;
    IF n <> 12 THEN bad := bad || format('expected 12 demo users, found %s', n); END IF;

    SELECT id INTO adm  FROM users WHERE email = 'admin@diamate.example';
    SELECT id INTO endo FROM users WHERE email = 'dr.endo@diamate.example';
    SELECT id INTO dia  FROM users WHERE email = 'dr.diabetes@diamate.example';
    SELECT id INTO cg   FROM users WHERE email = 'caregiver@diamate.example';
    SELECT id INTO p1   FROM users WHERE email = 'patient01@diamate.example';
    SELECT id INTO p6   FROM users WHERE email = 'patient06@diamate.example';
    SELECT id INTO p7   FROM users WHERE email = 'patient07@diamate.example';
    SELECT id INTO p8   FROM users WHERE email = 'patient08@diamate.example';

    -- access rules
    IF NOT fn_can_access(p1, p1, 'glucose')       THEN bad := bad || 'patient cannot see own data'; END IF;
    IF NOT fn_can_access(endo, p1, 'glucose')     THEN bad := bad || 'active clinician cannot see patient01'; END IF;
    IF fn_can_access(dia, p1, 'glucose')          THEN bad := bad || 'PENDING clinician can see patient01'; END IF;
    IF fn_can_access(dia, p6, 'glucose')          THEN bad := bad || 'REVOKED clinician can still see patient06'; END IF;
    IF fn_can_access(adm, p1, 'glucose')          THEN bad := bad || 'ADMIN has access to health data'; END IF;
    IF NOT fn_can_access(cg, p7, 'glucose')       THEN bad := bad || 'caregiver cannot see patient07 glucose'; END IF;
    IF fn_can_access(cg, p8, 'meals')             THEN bad := bad || 'caregiver can see patient08 meals (flag is false)'; END IF;
    IF fn_can_access(cg, p7, 'reports')           THEN bad := bad || 'caregiver can see patient07 reports (flag is false)'; END IF;

    -- data present for every demo patient
    SELECT count(*) INTO n FROM patient_profiles p WHERE p.research_patient_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM glucose_logs g WHERE g.patient_id = p.user_id);
    IF n > 0 THEN bad := bad || format('%s demo patients without glucose logs', n); END IF;
    SELECT count(*) INTO n FROM v_patient_overview WHERE is_demo AND last_glucose_at < now() - interval '2 days';
    IF n > 0 THEN bad := bad || format('%s demo patients whose newest reading is older than 2 days', n); END IF;
    SELECT count(*) INTO n FROM v_glucose_14d WHERE n_readings > 0 AND (tir_pct + tbr_pct + tar_pct) NOT BETWEEN 99.5 AND 100.5;
    IF n > 0 THEN bad := bad || format('%s patients whose TIR/TBR/TAR do not add up to 100', n); END IF;

    IF array_length(bad, 1) IS NOT NULL THEN
        RAISE EXCEPTION E'VERIFY FAILED:\n  - %', array_to_string(bad, E'\n  - ');
    END IF;
    RAISE NOTICE 'demo checks passed';
END $$;

-- the demo password must open every demo account (bcrypt check through pgcrypto)
SELECT count(*) AS demo_users, bool_and(password_hash = crypt(:'demo_password', password_hash)) AS all_passwords_ok
FROM users WHERE is_demo;

\echo
\echo === demo patients: last 14 days ===
SELECT o.full_name, o.diabetes_type AS type, o.therapy_type AS therapy, o.last_glucose_mgdl AS last_mgdl,
       s.n_readings, s.mean_mgdl, s.gmi_pct, s.cv_pct, s.tir_pct, s.tbr_pct, s.tar_pct, o.open_alerts
FROM v_patient_overview o LEFT JOIN v_glucose_14d s ON s.patient_id = o.patient_id
WHERE o.is_demo ORDER BY o.full_name;

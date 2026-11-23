-- DiaMate: tests of the data-level access rule fn_can_access (who may read which patient's data) on a real database.
-- Everything runs inside ONE transaction that is rolled back: no rows stay behind, the demo data is not used.
-- Any failed check stops the script with "FAIL: ..." and a non-zero exit code.
--
--   psql -d diamate -f tools/access_rules_test.sql
--   docker exec -i diamate-postgres psql -U diamate -d diamate < tools/access_rules_test.sql   (local Docker DB)
--
-- The backend asks fn_can_access(viewer, patient, permission) for every read of a patient's data
-- (DiaMate/src/main/java/com/diamate/backend/service/PatientDataType.java maps each data type to a permission).
\set ON_ERROR_STOP on
\set QUIET on
BEGIN;

-- Test accounts (rolled back at the end). Emails use the reserved .invalid domain so they can never collide.
CREATE TEMP TABLE t_user (k text PRIMARY KEY, id bigint) ON COMMIT DROP;
WITH new_users AS (
    INSERT INTO users (email, password_hash, role, first_name, last_name, is_active)
    VALUES ('acl-patient@test.invalid',   'x', 'PATIENT',   'Acl', 'Patient', true),
           ('acl-other@test.invalid',     'x', 'PATIENT',   'Acl', 'Other',   true),
           ('acl-closed@test.invalid',    'x', 'PATIENT',   'Acl', 'Closed',  false),
           ('acl-doctor@test.invalid',    'x', 'CLINICIAN', 'Acl', 'Doctor',  true),
           ('acl-carer@test.invalid',     'x', 'CAREGIVER', 'Acl', 'Carer',   true),
           ('acl-pending@test.invalid',   'x', 'CLINICIAN', 'Acl', 'Pending', true),
           ('acl-declined@test.invalid',  'x', 'CAREGIVER', 'Acl', 'Declined', true),
           ('acl-revoked@test.invalid',   'x', 'CLINICIAN', 'Acl', 'Revoked', true),
           ('acl-expired@test.invalid',   'x', 'CLINICIAN', 'Acl', 'Expired', true),
           ('acl-future@test.invalid',    'x', 'CAREGIVER', 'Acl', 'Future',  true),
           ('acl-disabled@test.invalid',  'x', 'CLINICIAN', 'Acl', 'Disabled', false),
           ('acl-nothing@test.invalid',   'x', 'CAREGIVER', 'Acl', 'Nothing', true),
           ('acl-admin@test.invalid',     'x', 'ADMIN',     'Acl', 'Admin',   true)
    RETURNING id, split_part(split_part(email, '@', 1), '-', 2) AS k)
INSERT INTO t_user SELECT k, id FROM new_users;
CREATE FUNCTION pg_temp.u(text) RETURNS bigint LANGUAGE sql STABLE AS $$ SELECT id FROM t_user WHERE k = $1 $$;

INSERT INTO patient_profiles (user_id, diabetes_type)
VALUES (pg_temp.u('patient'), 'TYPE_1'), (pg_temp.u('other'), 'TYPE_2'), (pg_temp.u('closed'), 'TYPE_1');

INSERT INTO care_relationships (patient_id, member_id, member_role, status, expires_at,
        can_view_glucose, can_view_meals, can_view_medications, can_view_activity, can_view_reports,
        can_receive_alerts, can_add_recommendations)
VALUES
    -- doctor: ACTIVE, everything shared except meals
    (pg_temp.u('patient'), pg_temp.u('doctor'),   'CLINICIAN', 'ACTIVE',   NULL,                 true,  false, true,  true,  true,  true,  true),
    -- carer: ACTIVE, only glucose and alerts
    (pg_temp.u('patient'), pg_temp.u('carer'),    'CAREGIVER', 'ACTIVE',   NULL,                 true,  false, false, false, false, true,  false),
    (pg_temp.u('patient'), pg_temp.u('pending'),  'CLINICIAN', 'PENDING',  NULL,                 true,  true,  true,  true,  true,  true,  true),
    (pg_temp.u('patient'), pg_temp.u('declined'), 'CAREGIVER', 'DECLINED', NULL,                 true,  true,  true,  true,  true,  true,  false),
    (pg_temp.u('patient'), pg_temp.u('revoked'),  'CLINICIAN', 'REVOKED',  NULL,                 true,  true,  true,  true,  true,  true,  true),
    (pg_temp.u('patient'), pg_temp.u('expired'),  'CLINICIAN', 'ACTIVE',   now() - interval '1 minute', true, true, true, true, true, true, true),
    (pg_temp.u('patient'), pg_temp.u('future'),   'CAREGIVER', 'ACTIVE',   now() + interval '1 day',    true, true, true, true, true, true, false),
    (pg_temp.u('patient'), pg_temp.u('disabled'), 'CLINICIAN', 'ACTIVE',   NULL,                 true,  true,  true,  true,  true,  true,  true),
    -- nothing: ACTIVE, but every flag off
    (pg_temp.u('patient'), pg_temp.u('nothing'),  'CAREGIVER', 'ACTIVE',   NULL,                 false, false, false, false, false, false, false),
    -- the doctor also cares for a patient whose account an ADMIN stopped (V8)
    (pg_temp.u('closed'),  pg_temp.u('doctor'),   'CLINICIAN', 'ACTIVE',   NULL,                 true,  true,  true,  true,  true,  true,  true);

-- Expected answers: viewer x permission. Unknown permission names must be false for everyone except the patient.
CREATE TEMP TABLE t_expect (viewer text, patient text, permission text, expected boolean) ON COMMIT DROP;
INSERT INTO t_expect VALUES
    -- the patient sees all of their own data, under any permission name
    ('patient', 'patient', 'glucose', true), ('patient', 'patient', 'meals', true), ('patient', 'patient', 'medications', true),
    ('patient', 'patient', 'activity', true), ('patient', 'patient', 'reports', true), ('patient', 'patient', 'alerts', true),
    ('patient', 'patient', 'recommend', true), ('patient', 'patient', 'no-such-permission', true),
    -- ... but not another patient's
    ('patient', 'other', 'glucose', false), ('other', 'patient', 'glucose', false), ('other', 'patient', 'alerts', false),
    -- doctor: each flag on its own
    ('doctor', 'patient', 'glucose', true), ('doctor', 'patient', 'meals', false), ('doctor', 'patient', 'medications', true),
    ('doctor', 'patient', 'activity', true), ('doctor', 'patient', 'reports', true), ('doctor', 'patient', 'alerts', true),
    ('doctor', 'patient', 'recommend', true), ('doctor', 'patient', 'no-such-permission', false),
    ('doctor', 'patient', 'GLUCOSE', true),                    -- permission names are case-insensitive
    ('doctor', 'other', 'glucose', false),                     -- a relationship covers one patient only
    -- carer: only glucose and alerts
    ('carer', 'patient', 'glucose', true), ('carer', 'patient', 'alerts', true), ('carer', 'patient', 'meals', false),
    ('carer', 'patient', 'medications', false), ('carer', 'patient', 'activity', false), ('carer', 'patient', 'reports', false),
    ('carer', 'patient', 'recommend', false),
    -- relationship states other than ACTIVE give nothing, even with every flag on
    ('pending', 'patient', 'glucose', false), ('pending', 'patient', 'alerts', false),
    ('declined', 'patient', 'glucose', false), ('declined', 'patient', 'alerts', false),
    ('revoked', 'patient', 'glucose', false), ('revoked', 'patient', 'alerts', false),
    -- expiry: past = nothing, future = still shared
    ('expired', 'patient', 'glucose', false), ('expired', 'patient', 'alerts', false),
    ('future', 'patient', 'glucose', true), ('future', 'patient', 'meals', true),
    -- a deactivated member loses access at once
    ('disabled', 'patient', 'glucose', false), ('disabled', 'patient', 'alerts', false),
    -- ACTIVE with every flag off = nothing
    ('nothing', 'patient', 'glucose', false), ('nothing', 'patient', 'alerts', false), ('nothing', 'patient', 'meals', false),
    -- an inactive patient's data is closed to the care team (V8); the care-team list already hid them
    ('doctor', 'closed', 'glucose', false), ('doctor', 'closed', 'alerts', false), ('doctor', 'closed', 'meals', false),
    -- ADMIN has no implicit access to health data
    ('admin', 'patient', 'glucose', false), ('admin', 'patient', 'alerts', false), ('admin', 'other', 'glucose', false);

DO $$
DECLARE
    r record;
    got boolean;
    n int := 0;
BEGIN
    FOR r IN SELECT * FROM t_expect LOOP
        got := fn_can_access(pg_temp.u(r.viewer), pg_temp.u(r.patient), r.permission);
        IF got IS DISTINCT FROM r.expected THEN
            RAISE EXCEPTION 'FAIL: fn_can_access(%, %, %) = %, expected %', r.viewer, r.patient, r.permission, got, r.expected;
        END IF;
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'fn_can_access matrix: % checks passed', n;
END $$;

-- Changes take effect at once (no cache): the patient turns meals on, revokes the carer, the doctor's relationship expires.
DO $$
BEGIN
    UPDATE care_relationships SET can_view_meals = true
        WHERE member_id = pg_temp.u('doctor') AND patient_id = pg_temp.u('patient');
    IF NOT fn_can_access(pg_temp.u('doctor'), pg_temp.u('patient'), 'meals') THEN
        RAISE EXCEPTION 'FAIL: meals turned on, doctor still cannot read meals';
    END IF;

    UPDATE care_relationships SET status = 'REVOKED' WHERE member_id = pg_temp.u('carer');
    IF fn_can_access(pg_temp.u('carer'), pg_temp.u('patient'), 'glucose') THEN
        RAISE EXCEPTION 'FAIL: carer revoked, still reads glucose';
    END IF;
    IF (SELECT revoked_at FROM care_relationships WHERE member_id = pg_temp.u('carer')) IS NULL THEN
        RAISE EXCEPTION 'FAIL: revoking did not set revoked_at (trg_care_guard)';
    END IF;

    UPDATE care_relationships SET expires_at = now() - interval '1 second'
        WHERE member_id = pg_temp.u('doctor') AND patient_id = pg_temp.u('patient');
    IF fn_can_access(pg_temp.u('doctor'), pg_temp.u('patient'), 'glucose') THEN
        RAISE EXCEPTION 'FAIL: relationship expired, doctor still reads glucose';
    END IF;

    UPDATE users SET is_active = true WHERE id = pg_temp.u('disabled');
    IF NOT fn_can_access(pg_temp.u('disabled'), pg_temp.u('patient'), 'glucose') THEN
        RAISE EXCEPTION 'FAIL: member re-activated, access did not come back';
    END IF;

    UPDATE users SET is_active = true WHERE id = pg_temp.u('closed');
    IF NOT fn_can_access(pg_temp.u('doctor'), pg_temp.u('closed'), 'glucose') THEN
        RAISE EXCEPTION 'FAIL: patient re-activated, the care team did not get access back';
    END IF;
    RAISE NOTICE 'immediate changes: 6 checks passed';
END $$;

-- Database guards behind the API rules.
DO $$
BEGIN
    BEGIN
        INSERT INTO care_relationships (patient_id, member_id, member_role, status)
        VALUES (pg_temp.u('patient'), pg_temp.u('carer'), 'CLINICIAN', 'PENDING');   -- carer's real role is CAREGIVER
        RAISE EXCEPTION 'FAIL: member_role different from the account role was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO care_relationships (patient_id, member_id, member_role, status)
        VALUES (pg_temp.u('patient'), pg_temp.u('doctor'), 'CLINICIAN', 'PENDING');  -- doctor already has an open one
        RAISE EXCEPTION 'FAIL: a second open relationship for the same pair was accepted';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO care_relationships (patient_id, member_id, member_role, status)
        VALUES (pg_temp.u('admin'), pg_temp.u('doctor'), 'CLINICIAN', 'PENDING');    -- admin has no patient profile
        RAISE EXCEPTION 'FAIL: a relationship for an account without a patient profile was accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    RAISE NOTICE 'database guards: 3 checks passed';
END $$;

ROLLBACK;
\echo access_rules_test: OK (all changes rolled back)

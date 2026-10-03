-- V2: users get first_name / last_name instead of a single full_name, plus date_of_birth and gender.
--
-- Registration now asks every user (not only patients) for a date of birth (minimum age 16, checked by the
-- backend) and a gender, so both move from patient_profiles to users. full_name stays as a column generated
-- from first_name and last_name, so views, reports and the read-only role keep working.

-- 1) New columns (nullable for now, filled below)
ALTER TABLE users
    ADD COLUMN first_name    varchar(50),
    ADD COLUMN last_name     varchar(50),
    ADD COLUMN date_of_birth date,
    ADD COLUMN gender        varchar(10);

-- 2) Split existing names: the last word is the last name, everything before it the first name(s).
--    "Ayşe Nur Yılmaz" -> first_name "Ayşe Nur", last_name "Yılmaz". A single word is used for both.
UPDATE users
SET first_name = CASE WHEN btrim(full_name) ~ '\s'
                      THEN regexp_replace(btrim(full_name), '\s+\S+$', '')
                      ELSE btrim(full_name) END,
    last_name  = substring(btrim(full_name) FROM '(\S+)$');

-- 3) Copy date of birth and sex of existing patients from their profile
UPDATE users u
SET date_of_birth = p.date_of_birth,
    gender        = p.sex
FROM patient_profiles p
WHERE p.user_id = u.id;

-- 4) Constraints. date_of_birth and gender stay nullable: older accounts (demo admin, clinicians, caregivers)
--    never had them. The backend requires both for every new registration.
ALTER TABLE users
    ALTER COLUMN first_name SET NOT NULL,
    ALTER COLUMN last_name  SET NOT NULL,
    ADD CONSTRAINT users_first_name_not_blank CHECK (btrim(first_name) <> ''),
    ADD CONSTRAINT users_last_name_not_blank  CHECK (btrim(last_name) <> ''),
    ADD CONSTRAINT users_gender_check         CHECK (gender IN ('FEMALE', 'MALE', 'OTHER')),
    ADD CONSTRAINT users_date_of_birth_check  CHECK (date_of_birth >= DATE '1900-01-01');

-- 5) Views that read the columns being replaced are dropped and recreated below
DROP VIEW v_care_team;
DROP VIEW v_patient_overview;

-- 6) full_name is now derived from first_name and last_name (never written directly)
ALTER TABLE users DROP COLUMN full_name;
ALTER TABLE users ADD COLUMN full_name varchar(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED;

-- 7) date of birth and sex now live on users
ALTER TABLE patient_profiles
    DROP COLUMN date_of_birth,
    DROP COLUMN sex;

-- 8) Recreate the views (same columns as before; "sex" is now called "gender" and comes from users)
CREATE VIEW v_patient_overview AS
SELECT u.id                         AS patient_id,
       u.email, u.full_name, u.first_name, u.last_name, u.is_active, u.is_demo,
       p.diabetes_type, p.therapy_type, u.gender,
       date_part('year', age(u.date_of_birth))::int AS age_years,
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

CREATE VIEW v_care_team AS
SELECT r.id AS relationship_id, r.patient_id, pu.full_name AS patient_name,
       r.member_id, mu.full_name AS member_name, mu.email AS member_email, r.member_role, r.status,
       r.can_view_glucose, r.can_view_meals, r.can_view_medications, r.can_view_activity, r.can_view_reports,
       r.can_receive_alerts, r.can_add_recommendations, r.invited_at, r.responded_at, r.expires_at
FROM care_relationships r
JOIN users pu ON pu.id = r.patient_id
JOIN users mu ON mu.id = r.member_id;

-- 9) Privileges. The views get their grants from the default privileges set by Database/sql/10_grants.sql.
--    The read-only role only sees selected users columns: keep the name visible and keep the demographics
--    it could already read in patient_profiles.
GRANT SELECT (first_name, last_name, full_name, date_of_birth, gender) ON users TO diamate_readonly;

COMMENT ON COLUMN users.first_name    IS 'First name(s), required.';
COMMENT ON COLUMN users.last_name     IS 'Last name, required.';
COMMENT ON COLUMN users.full_name     IS 'Generated: first_name || '' '' || last_name. Read-only.';
COMMENT ON COLUMN users.date_of_birth IS 'Required at registration; self-registration needs age >= 16 (checked by the backend). NULL only for accounts created before V2.';
COMMENT ON COLUMN users.gender        IS 'FEMALE, MALE or OTHER. Required at registration; NULL only for accounts created before V2.';

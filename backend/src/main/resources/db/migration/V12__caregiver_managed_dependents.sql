-- V12: a caregiver can add a family member without an account (a child) and keep their diary for them.
--
-- (Planned as "V9"; V9..V11 were already taken, so this is V12.)
--
-- 1) users: an account-less person is a PATIENT row without email and password. Either both are there (an account
--    that can log in) or neither (a dependent). Only a patient can be a dependent.
-- 2) care_relationships.manages_patient: "this caregiver manages this patient". Only a CAREGIVER, only for a patient
--    without an account (so nobody can take over the diary of a patient who has their own login), at most one open
--    manager per patient, no end date.
-- 3) fn_can_access: the managing caregiver sees every data type (except 'recommend', a clinician's permission) and
--    has the new 'write' permission. The patient themself also has 'write'; nobody else has it.
-- 4) auth_sessions: a session (a login) can only be opened for a user with a password. With this and 1), an
--    account-less record can never log in, whatever the backend does.

-- ------------------------------------------------------------------------------------------------------------- 1
ALTER TABLE users
    ALTER COLUMN email         DROP NOT NULL,
    ALTER COLUMN password_hash DROP NOT NULL,
    ADD CONSTRAINT ck_users_login_complete    CHECK ((email IS NULL) = (password_hash IS NULL)),
    ADD CONSTRAINT ck_users_dependent_patient CHECK (email IS NOT NULL OR role = 'PATIENT');

COMMENT ON COLUMN users.email         IS 'Login email (unique, case-insensitive). NULL only for a dependent (a patient without an account, managed by a caregiver).';
COMMENT ON COLUMN users.password_hash IS 'bcrypt, written by the backend only. NULL exactly when email is NULL: a dependent, who can never log in.';

-- ------------------------------------------------------------------------------------------------------------- 2
ALTER TABLE care_relationships
    ADD COLUMN manages_patient boolean NOT NULL DEFAULT false,
    ADD CONSTRAINT ck_care_manager_is_caregiver CHECK (NOT manages_patient OR member_role = 'CAREGIVER'),
    ADD CONSTRAINT ck_care_manager_no_expiry    CHECK (NOT manages_patient OR expires_at IS NULL);

CREATE UNIQUE INDEX ux_care_one_manager ON care_relationships (patient_id)
    WHERE manages_patient AND status IN ('PENDING', 'ACTIVE');
CREATE INDEX ix_care_managed_by ON care_relationships (member_id) WHERE manages_patient AND status = 'ACTIVE';

COMMENT ON COLUMN care_relationships.manages_patient IS 'true: this caregiver manages a dependent (a patient without an account): sees all data and writes it (fn_can_access ''write'').';

CREATE FUNCTION care_manager_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.manages_patient AND EXISTS (SELECT 1 FROM users WHERE id = NEW.patient_id AND password_hash IS NOT NULL) THEN
        RAISE EXCEPTION 'patient % has an account and cannot be managed by a caregiver', NEW.patient_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_care_manager_guard BEFORE INSERT OR UPDATE OF manages_patient, patient_id ON care_relationships
    FOR EACH ROW EXECUTE FUNCTION care_manager_guard();

-- ------------------------------------------------------------------------------------------------------------- 3
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
                      WHEN 'glucose'     THEN r.can_view_glucose     OR r.manages_patient
                      WHEN 'meals'       THEN r.can_view_meals       OR r.manages_patient
                      WHEN 'medications' THEN r.can_view_medications OR r.manages_patient
                      WHEN 'activity'    THEN r.can_view_activity    OR r.manages_patient
                      WHEN 'reports'     THEN r.can_view_reports     OR r.manages_patient
                      WHEN 'alerts'      THEN r.can_receive_alerts   OR r.manages_patient
                      WHEN 'recommend'   THEN r.can_add_recommendations
                      WHEN 'write'       THEN r.manages_patient
                      ELSE false
                  END
        )
$$;

COMMENT ON FUNCTION fn_can_access IS 'Authorisation helper: patient itself, or clinician/caregiver with an ACTIVE, not expired care relationship that grants the permission, both accounts active. A managing caregiver (manages_patient) has every view permission and ''write''.';

-- ------------------------------------------------------------------------------------------------------------- 4
CREATE FUNCTION auth_session_requires_login() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.user_id AND password_hash IS NOT NULL AND email IS NOT NULL) THEN
        RAISE EXCEPTION 'user % has no login and cannot open a session', NEW.user_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_auth_session_requires_login BEFORE INSERT OR UPDATE OF user_id ON auth_sessions
    FOR EACH ROW EXECUTE FUNCTION auth_session_requires_login();

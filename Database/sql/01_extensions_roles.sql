-- DiaMate database, step 1: extensions and database roles
-- Run as a superuser (e.g. postgres) inside the target database.
\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS pgcrypto;      -- bcrypt hashes for the demo accounts (crypt / gen_salt); gen_random_uuid()

-- Application roles. They are created NOLOGIN on purpose (no default password in any file).
-- To use them:  ALTER ROLE diamate_app LOGIN PASSWORD '<your password>';
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'diamate_app') THEN
        CREATE ROLE diamate_app NOLOGIN;      -- what the Spring Boot backend connects as (DML on public, read on research)
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'diamate_readonly') THEN
        CREATE ROLE diamate_readonly NOLOGIN; -- analysts / AI service: read-only on everything
    END IF;
END
$$;

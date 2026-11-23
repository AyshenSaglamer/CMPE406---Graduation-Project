-- DiaMate: privileges for the application roles (roles are created NOLOGIN in 01_extensions_roles.sql)
--   diamate_app       what the Spring Boot backend connects as: read/write on public, read-only on research
--   diamate_readonly  analysts / the AI service: read-only everywhere
-- To let a role log in:   ALTER ROLE diamate_app LOGIN PASSWORD '<choose a password>';
\set ON_ERROR_STOP on

GRANT USAGE ON SCHEMA public, research TO diamate_app, diamate_readonly;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO diamate_app;
REVOKE UPDATE, DELETE, TRUNCATE ON audit_logs FROM diamate_app;            -- audit trail is append-only
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO diamate_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO diamate_app;
GRANT SELECT ON ALL TABLES IN SCHEMA research TO diamate_app;

GRANT SELECT ON ALL TABLES IN SCHEMA public, research TO diamate_readonly;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO diamate_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO diamate_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO diamate_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO diamate_readonly;

-- the password hashes and 2FA secrets must never be readable by the read-only role
REVOKE ALL ON users FROM diamate_readonly;
GRANT SELECT (id, role, full_name, is_active, is_demo, created_at) ON users TO diamate_readonly;
REVOKE ALL ON refresh_tokens, password_reset_tokens, device_tokens FROM diamate_readonly;

-- Flyway callback (not a versioned migration, not recorded in flyway_schema_history): runs after every migrate, both
-- in the docker-compose migrate service and when the backend migrates by itself (Neon, IDE, tests).
--
-- Database/sql/10_grants.sql gives diamate_app SELECT/INSERT/UPDATE/DELETE on every table the owner creates later
-- (ALTER DEFAULT PRIVILEGES). That also covers flyway_schema_history, which Flyway creates on the first migrate, so the
-- application role could rewrite or delete the migration history. The application never needs that table.
--
-- Only when the role exists: a database set up without the Database/sql package has no diamate_app.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'diamate_app') THEN
        REVOKE ALL ON TABLE flyway_schema_history FROM diamate_app;
    END IF;
END
$$;

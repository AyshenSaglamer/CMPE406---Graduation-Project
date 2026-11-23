-- Runs once, on the first start of an empty database volume (docker-compose.yml mounts it into
-- /docker-entrypoint-initdb.d after the Database/sql scripts). It lets the application role log in.
--
-- diamate_app is created NOLOGIN in 01_extensions_roles.sql and gets only DML rights in 10_grants.sql (no DDL, no
-- UPDATE/DELETE/TRUNCATE on audit_logs). The backend connects as this role; schema changes are made by the separate
-- migrate service (Flyway) with the owner account, so the running backend never holds the owner's password.
--
-- A .sql file, not a .sh: the image runs .sql files with psql, while a .sh file depends on its file mode, which
-- Docker Desktop's file sharing does not report reliably ("bad interpreter: Permission denied").
--
-- For a volume created before this script existed, run once by hand:
--   docker compose exec database psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
--       -c "ALTER ROLE diamate_app LOGIN PASSWORD '<APP_DB_PASSWORD from .env>'"
\set ON_ERROR_STOP on

-- The password comes from the container's environment (docker-compose.yml: APP_DB_PASSWORD) into a psql variable and
-- is quoted by :'...'; it is never written into this file. If the variable is missing, :'app_db_password' is left as
-- it is and the statement fails, which stops the database's first start instead of leaving the role without a password.
\getenv app_db_password APP_DB_PASSWORD
ALTER ROLE diamate_app LOGIN PASSWORD :'app_db_password';

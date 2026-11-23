-- =====================================================================================================================
-- DANGER: deletes EVERYTHING in the current database (schemas public and research), then runs the full install.
-- Use it to start over or to replace an older DiaMate load. Same variables as run_all.sql.
--   psql -h localhost -p 5433 -U postgres -d diamate -v data_dir="/Users/melihkocabyk/Desktop/Graduate Project" -f reset_and_run_all.sql
-- Requires PostgreSQL 15+. Database roles diamate_app / diamate_readonly are kept.
-- =====================================================================================================================
\set ON_ERROR_STOP on
\echo Dropping schemas research and public in database :DBNAME ...
DROP SCHEMA IF EXISTS research CASCADE;
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public AUTHORIZATION pg_database_owner;
GRANT USAGE ON SCHEMA public TO PUBLIC;
COMMENT ON SCHEMA public IS 'standard public schema';
\ir run_all.sql

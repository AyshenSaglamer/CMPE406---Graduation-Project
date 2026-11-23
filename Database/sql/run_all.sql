-- =====================================================================================================================
-- DiaMate database: full install (run inside the empty target database, as a superuser such as postgres)
--
--   psql -h localhost -p 5433 -U postgres -d diamate -v data_dir="/Users/melihkocabyk/Desktop/Graduate Project" -f run_all.sql
--   (data_dir = project root that contains Dataset/unified/ and Database/data/)
--
-- Optional variables:  -v load_demo=0            skip the demo accounts / demo data (schema + reference data only)
--                      -v demo_password='...'    password of the demo accounts (default DiaMate!2026)
-- Inside pgAdmin's PSQL Tool:   \i '/Users/melihkocabyk/Desktop/Graduate Project/Database/sql/run_all.sql'
--
-- Order: 01 extensions/roles | 02-05 research schema (open datasets) | 06 application schema (+06b column comments), 07 functions and views |
--        08 reference data | 09 demo data | 10 grants | 11 verification
-- =====================================================================================================================
\set ON_ERROR_STOP on
\encoding UTF8
\if :{?data_dir}
\else
\set data_dir '/Users/melihkocabyk/Desktop/Graduate Project'
\endif
\if :{?demo_password}
\else
\set demo_password 'DiaMate!2026'
\endif
\if :{?load_demo}
\else
\set load_demo 1
\endif
\timing off
\echo
\echo ===== DiaMate install: data_dir = :data_dir =====

\echo [01] extensions and roles
\ir 01_extensions_roles.sql
\echo [02] research schema
\ir 02_research_schema.sql
\echo [03] loading research data (about 1 minute)
\ir 03_research_load.sql
\echo [04] research keys and indexes
\ir 04_research_keys_indexes.sql
\echo [05] research verification
\ir 05_research_verify.sql
\echo [06] application schema
\ir 06_app_schema.sql
\ir 06b_app_column_comments.sql
\echo [07] functions and views
\ir 07_app_functions_views.sql
\echo [08] reference data (food catalog)
\ir 08_reference_seed.sql
\if :load_demo
\echo [09] demo accounts and demo data
\ir 09_demo_seed.sql
\else
\echo [09] demo data skipped (load_demo=0)
\endif
\echo [10] grants
\ir 10_grants.sql
\echo [11] verification
\ir 11_verify.sql
\echo
\echo ===== DiaMate install finished =====

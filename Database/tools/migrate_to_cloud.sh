#!/usr/bin/env bash
# Copies the local DiaMate database (public + research) into a cloud PostgreSQL (Neon / Supabase).
# Run on the Mac that has the local database. Needs psql, pg_dump, pg_restore (Homebrew postgresql@18).
#
#   export SRC_PASSWORD=...            # local database password
#   export DST_URL='postgresql://user:pass@host/db?sslmode=require'   # cloud DIRECT (non-pooled) connection string
#   MODE=lite ./migrate_to_cloud.sh    # lite (default): skips big, rarely-needed research tables' data
#   MODE=full ./migrate_to_cloud.sh    # everything (needs a cloud plan with > 1 GB storage)
#
# Never commit the connection string. Tables skipped in lite mode keep their structure (empty), so queries still run.
set -euo pipefail
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"

SRC_HOST="${SRC_HOST:-localhost}"; SRC_PORT="${SRC_PORT:-5435}"
SRC_USER="${SRC_USER:-diamate}";   SRC_DB="${SRC_DB:-diamate}"
# Secrets are asked interactively (hidden input) when not already exported, so nothing lands in shell history.
if [ -z "${SRC_PASSWORD:-}" ]; then read -r -s -p "Yerel veritabani sifresi (diamate): " SRC_PASSWORD; echo; fi
if [ -z "${DST_URL:-}" ]; then read -r -s -p "Neon direct connection string: " DST_URL; echo; fi
: "${SRC_PASSWORD:?empty}"; : "${DST_URL:?empty}"
# Accept wrappers such as: psql 'postgresql://...'  or  DATABASE_URL="postgresql://..."
DST_URL="$(printf '%s' "$DST_URL" | grep -Eo "postgres(ql)?://[^'\" [:space:]]+" | head -n1 || true)"
case "$DST_URL" in postgres://*|postgresql://*) ;; *) echo "HATA: yapistirilan metinde postgresql:// ile baslayan bir baglanti dizesi bulunamadi. Neon'da Connect > 'Pooled connection' kapali olsun ve dizeyi tekrar kopyala."; exit 1;; esac
MODE="${MODE:-lite}"
export PGPASSWORD="$SRC_PASSWORD"
SRC=(-h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -d "$SRC_DB")

echo "== Local size by schema =="
psql "${SRC[@]}" -c "select schemaname, pg_size_pretty(sum(pg_total_relation_size(relid))) size from pg_statio_user_tables group by 1 order by sum(pg_total_relation_size(relid)) desc;"
echo "== Biggest tables =="
psql "${SRC[@]}" -c "select relname, pg_size_pretty(pg_total_relation_size(relid)) size from pg_statio_user_tables order by pg_total_relation_size(relid) desc limit 8;"

EXCL=()
if [ "$MODE" = "lite" ]; then
  # Largest / least useful for day-to-day backend work. Re-add by moving them out of this list.
  for t in research.brfss_survey research.food_images research.activity research.timeline; do EXCL+=(--exclude-table-data="$t"); done
  echo "MODE=lite: data of brfss_survey, food_images, activity, timeline is skipped."
fi

DUMP="$(mktemp -t diamate_XXXX).dump"; trap 'rm -f "$DUMP"' EXIT
pg_dump "${SRC[@]}" -Fc --no-owner --no-privileges "${EXCL[@]}" -f "$DUMP"
ls -lh "$DUMP"

echo "== Restoring into cloud =="
pg_restore --no-owner --no-privileges --clean --if-exists -d "$DST_URL" "$DUMP" || echo "(pg_restore reported warnings - check above; role/extension warnings are usually harmless)"

echo "== Roller (V2 migration GRANT ... TO diamate_readonly icin gerekli) =="
psql "$DST_URL" -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='diamate_app') THEN CREATE ROLE diamate_app NOLOGIN; END IF; IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='diamate_readonly') THEN CREATE ROLE diamate_readonly NOLOGIN; END IF; END \$\$;"
echo "== Cloud check =="
psql "$DST_URL" -c "select pg_size_pretty(pg_database_size(current_database())) as db_size;" \
                -c "select count(*) as users from public.users;" \
                -c "select version, description from public.flyway_schema_history order by installed_rank;"

#!/usr/bin/env bash
# DiaMate: installs the database (schemas, data, demo accounts) with psql. macOS / Linux.
#
#   ./install_mac.sh                install into an EMPTY database
#   ./install_mac.sh --reset        first delete everything in the database (schemas public + research), then install
#   ./install_mac.sh --no-demo      skip demo accounts and demo data
#
# Connection (defaults match pgAdmin's server on this Mac): PGHOST=localhost PGPORT=5433 PGUSER=postgres PGDATABASE=diamate
# The password is asked interactively (or taken from the PGPASSWORD environment variable). It is never written to disk.
#
# Folder layout expected:  <project root>/Database/  (this script)   and   <project root>/Dataset/unified/  (the CSV tables)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"                        # the 'Graduate Project' folder: contains Dataset/ and Database/
[ -d "$ROOT/Dataset/unified" ] || { echo "Dataset/unified not found next to Database/ (looked in $ROOT)"; exit 1; }
PSQL="${PSQL:-$(command -v psql || true)}"
[ -z "$PSQL" ] && [ -x /opt/homebrew/bin/psql ] && PSQL=/opt/homebrew/bin/psql
[ -z "$PSQL" ] && { echo "psql not found. Install it (brew install libpq) or set PSQL=/path/to/psql"; exit 1; }

export PGHOST="${PGHOST:-localhost}" PGPORT="${PGPORT:-5433}" PGUSER="${PGUSER:-postgres}" PGDATABASE="${PGDATABASE:-diamate}"
if [ -z "${PGPASSWORD:-}" ]; then
  read -r -s -p "PostgreSQL password for $PGUSER@$PGHOST:$PGPORT: " PGPASSWORD; echo
  export PGPASSWORD
fi

SCRIPT=run_all.sql; EXTRA=()
for a in "$@"; do
  case "$a" in
    --reset)   SCRIPT=reset_and_run_all.sql ;;
    --no-demo) EXTRA+=(-v load_demo=0) ;;
    *) echo "unknown option $a"; exit 1 ;;
  esac
done

echo "Installing into database '$PGDATABASE' on $PGHOST:$PGPORT (CSV data from $ROOT) using $SCRIPT"
cd "$HERE/sql"
"$PSQL" -X -v ON_ERROR_STOP=1 -v data_dir="$ROOT" ${EXTRA[@]+"${EXTRA[@]}"} -f "$SCRIPT"

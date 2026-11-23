#!/usr/bin/env bash
# Opens psql against the cloud database. Asks for the connection string (hidden), never stores it.
#   ./cloud_psql.sh                         interactive
#   ./cloud_psql.sh -c "select 1"           one command
set -euo pipefail
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
read -r -s -p "Neon connection string: " RAW; echo
URL="$(printf '%s' "$RAW" | grep -Eo "postgres(ql)?://[^'\" [:space:]]+" | head -n1 || true)"
[ -n "$URL" ] || { echo "HATA: postgresql:// dizesi bulunamadi."; exit 1; }
exec psql "$URL" "$@"

#!/bin/sh
# Backs up the DiaMate database to deploy/backups/diamate-YYYYMMDD-HHMMSS.sql.gz and keeps the last $KEEP (default 14).
# Run from cron on the server, e.g. every night at 03:00:
#   0 3 * * * /opt/diamate/deploy/backup-db.sh >> /var/log/diamate-backup.log 2>&1
# Restore: see deploy/DEPLOYMENT.md ("Yedekten geri dönme").
set -eu

cd "$(dirname "$0")/.."
KEEP=${KEEP:-14}
mkdir -p deploy/backups
chmod 700 deploy/backups
FILE="deploy/backups/diamate-$(date +%Y%m%d-%H%M%S).sql.gz"

# pg_dump runs inside the database container as the owner account (POSTGRES_USER), so the password never leaves it.
docker compose -f docker-compose.yml -f docker-compose.prod.yml exec -T database \
  sh -c 'pg_dump --clean --if-exists -U "$POSTGRES_USER" -d "$POSTGRES_DB"' | gzip > "$FILE"
chmod 600 "$FILE"
echo "$(date -Iseconds) backup written: $FILE ($(du -h "$FILE" | cut -f1))"

ls -1t deploy/backups/diamate-*.sql.gz | tail -n +$((KEEP + 1)) | xargs -r rm --

#!/usr/bin/env bash
# Nightly backup: PostgreSQL dump and the uploaded PDFs, kept for 14 days.
# Copy the backup folder off the server too (e.g. rclone to object storage) - a backup on the
# same disk does not survive losing the server.
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/preploop}"
DEST="${BACKUP_DIR:-/var/backups/preploop}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
COMPOSE=(docker compose -f "$APP_DIR/infra/production/docker-compose.yml"
  --env-file "$APP_DIR/infra/production/.env")

mkdir -p "$DEST"
chmod 700 "$DEST"
"${COMPOSE[@]}" exec -T db pg_dump -U preploop -d preploop --format=custom \
  > "$DEST/db-$STAMP.dump"
"${COMPOSE[@]}" run --rm --no-deps -T --entrypoint tar worker \
  -czf - -C /app/var uploads > "$DEST/uploads-$STAMP.tar.gz"
find "$DEST" -type f -mtime +"$KEEP_DAYS" -delete
echo "$(date -u) backup written: $DEST/db-$STAMP.dump, uploads-$STAMP.tar.gz"

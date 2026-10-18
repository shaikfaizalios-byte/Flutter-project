#!/usr/bin/env bash
# Deploy (or update) PrepLoop on the server: pull, build, migrate, restart.
#   bash /opt/preploop/infra/production/deploy.sh
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/preploop}"
COMPOSE=(docker compose -f "$APP_DIR/infra/production/docker-compose.yml"
  --env-file "$APP_DIR/infra/production/.env")

cd "$APP_DIR"
if [ ! -f infra/production/.env ]; then
  echo "Missing infra/production/.env (copy .env.example and fill it in)." >&2
  exit 1
fi
chmod 600 infra/production/.env

git pull --ff-only
"${COMPOSE[@]}" build
# Migrations run first (the api/worker wait for them); then everything (re)starts.
"${COMPOSE[@]}" up -d
"${COMPOSE[@]}" ps

DOMAIN="$(grep -E '^API_DOMAIN=' infra/production/.env | cut -d= -f2-)"
echo "Waiting for https://$DOMAIN/api/v1/health/ready ..."
for _ in $(seq 1 30); do
  if curl -fsS "https://$DOMAIN/api/v1/health/ready" > /dev/null 2>&1; then
    echo "PrepLoop is up at https://$DOMAIN"
    docker image prune -f > /dev/null
    exit 0
  fi
  sleep 5
done
echo "Not ready yet. Check: ${COMPOSE[*]} logs --tail 100" >&2
exit 1

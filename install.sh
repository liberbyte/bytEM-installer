#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}$(date +'%Y-%m-%d %H:%M:%S')${NC} $*"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "Docker is not installed."
docker compose version >/dev/null 2>&1 || die "The Docker Compose plugin is not installed."
[ -f .env ] || die ".env is missing. Run ./env_setup.sh first."

set -a
# shellcheck disable=SC1091
source .env
set +a

required=(DOMAIN_NAME MATRIX_SERVER_NAME TEST_USERNAME TEST_PASSWORD MATRIX_ADMIN_USERNAME MATRIX_ADMIN_PASSWORD BOT_USERNAME BOT_PASSWORD)
for variable_name in "${required[@]}"; do
  [ -n "${!variable_name:-}" ] || die "$variable_name is missing from .env. Re-run ./env_setup.sh."
done
[ "$MATRIX_ADMIN_USERNAME" != "$BOT_USERNAME" ] || \
  die "The test/admin and bot usernames are mixed together. Re-run ./env_setup.sh --force and enter separate accounts."

log "Validating deployment configuration"
docker compose --env-file .env config --quiet

log "Pulling the latest published bytEM images"
docker compose --env-file .env pull

# Releases before the Synapse 1.159 upgrade bind-mounted this host directory
# into /data. Preserve its signing key and media when moving to the named volume.
legacy_synapse_data="$SCRIPT_DIR/generated_config_files/synapse_config"
if [ -d "$legacy_synapse_data" ] && [ -n "$(find "$legacy_synapse_data" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  docker volume create bytem-synapse-data >/dev/null
  if ! docker run --rm --entrypoint sh \
      -v bytem-synapse-data:/data:ro \
      liberbyteadmin/bytem:synapse \
      -c 'find /data -mindepth 1 -maxdepth 1 -print -quit | grep -q .'; then
    log "Migrating legacy Synapse signing keys and media into bytem-synapse-data"
    docker run --rm --entrypoint sh \
      -v "$legacy_synapse_data:/legacy:ro" \
      -v bytem-synapse-data:/data \
      liberbyteadmin/bytem:synapse \
      -c 'cp -a /legacy/. /data/'
  fi
fi

if [ ! -f "certbot/conf/live/${DOMAIN_NAME}/fullchain.pem" ] || \
   [ ! -f "certbot/conf/live/${MATRIX_SERVER_NAME}/fullchain.pem" ]; then
  warn "TLS certificates are missing; starting certificate setup."
  "$SCRIPT_DIR/certbot.sh"
fi

log "Starting or upgrading the bytEM stack"
mkdir -p logs/nginx
docker compose --env-file .env up -d --remove-orphans

log "Waiting for service health checks"
deadline=$((SECONDS + 240))
while [ "$SECONDS" -lt "$deadline" ]; do
  unhealthy=$(docker compose ps --all --format json | \
    grep -c '"Health":"unhealthy"\|"State":"exited"\|"State":"dead"' || true)
  starting=$(docker compose ps --all --format json | \
    grep -c '"Health":"starting"\|"State":"created"\|"State":"restarting"' || true)
  if [ "$unhealthy" -gt 0 ]; then
    docker compose ps
    die "One or more services failed. Inspect them with: docker compose logs <service>"
  fi
  if [ "$starting" -eq 0 ]; then
    break
  fi
  sleep 5
done

docker compose ps

if [ "$SECONDS" -ge "$deadline" ]; then
  warn "Some health checks are still starting. Follow them with: docker compose ps"
else
  echo -e "${GREEN}bytEM is running.${NC}"
fi

echo "  Application: https://${DOMAIN_NAME}"
echo "  Matrix:      https://${MATRIX_SERVER_NAME}"
echo "  Test user:   @${TEST_USERNAME}:${MATRIX_SERVER_NAME}"
echo "  Bot user:    @${BOT_USERNAME}:${MATRIX_SERVER_NAME}"
echo
warn "The bot access token is acquired inside the services; .env is not rewritten."

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$DEPLOY_DIR"

[ -f .env ] || { echo "ERROR: .env is missing." >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a

echo "PRE-UPGRADE STATE ($(date -Iseconds))"
echo
echo "TLS certificates:"
for domain in "$BYTEM_DOMAIN" "$MATRIX_HOMESERVER"; do
  certificate="certbot/conf/live/${domain}/fullchain.pem"
  if [ -f "$certificate" ]; then
    echo "  OK  $domain ($(stat -c %y "$certificate" | cut -d. -f1))"
  else
    echo "  MISSING  $domain"
  fi
done

echo
echo "Persistent Docker volumes:"
for volume in bytem-rabbitmq-data bytem-rabbitmq-log bytem-synapse-db-data bytem-synapse-data bytem-solr-data; do
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    echo "  OK  $volume"
  else
    echo "  MISSING  $volume"
  fi
done

echo
echo "Containers:"
docker compose ps

if docker compose ps --status running --services | grep -qx bytem-synapse; then
  echo
  echo "Synapse federation whitelist:"
  docker exec bytem-synapse awk '
    /^federation_domain_whitelist:/ {printing=1}
    printing && /^[^[:space:]#]/ && !/^federation_domain_whitelist:/ {exit}
    printing {print}
  ' /data/homeserver.yaml
fi

echo
echo "The upgrade command preserves these volumes and certificates: ./install.sh"

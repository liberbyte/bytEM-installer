#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}$*${NC}"; }

[ -f .env ] || die ".env is missing. Run ./env_setup.sh first."
set -a
# shellcheck disable=SC1091
source .env
set +a

[ -n "${BYTEM_DOMAIN:-}" ] || die "BYTEM_DOMAIN is missing from .env."
[ -n "${MATRIX_HOMESERVER:-}" ] || die "MATRIX_HOMESERVER is missing from .env."
[ -n "${SSL_EMAIL:-}" ] || die "SSL_EMAIL is missing from .env."

mkdir -p certbot/conf certbot/www

# The two bytEM names, then every governance domain served from
# domain_files/<domain>/. nginx serves a governance domain only once its
# certificate exists, so a failure there is reported and does not stop the rest.
domains=("$BYTEM_DOMAIN" "$MATRIX_HOMESERVER")
for folder in domain_files/*/; do
  [ -d "$folder" ] && domains+=("$(basename "$folder")")
done

if [ "${1:-}" = "--self-signed" ]; then
  command -v openssl >/dev/null 2>&1 || die "openssl is required for self-signed certificates."
  for domain in "${domains[@]}"; do
    mkdir -p "certbot/conf/live/${domain}"
    openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
      -keyout "certbot/conf/live/${domain}/privkey.pem" \
      -out "certbot/conf/live/${domain}/fullchain.pem" \
      -subj "/CN=${domain}" >/dev/null 2>&1
  done
  warn "Created 30-day self-signed certificates for local testing. Browsers will warn about them."
else
  command -v docker >/dev/null 2>&1 || die "Docker is not installed."

  missing=()
  for domain in "${domains[@]}"; do
    [ -f "certbot/conf/live/${domain}/fullchain.pem" ] || missing+=("$domain")
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    echo "Renewing existing Let's Encrypt certificates through the nginx webroot..."
    docker run --rm \
      -v "$SCRIPT_DIR/certbot/conf:/etc/letsencrypt" \
      -v "$SCRIPT_DIR/certbot/www:/var/www/certbot" \
      certbot/certbot renew --webroot --webroot-path /var/www/certbot
  else
    warn "These DNS names must point to this host and inbound port 80 must be open:"
    printf '  %s\n' "${missing[@]}"
    echo

    docker compose stop bytem-nginx >/dev/null 2>&1 || true
    # The pre-merge deployment used this name and may still own port 80 during
    # the first upgrade to bytem-nginx.
    if docker ps --format '{{.Names}}' | grep -qx bytem-app; then
      docker stop bytem-app >/dev/null
    fi
    for domain in "${missing[@]}"; do
      echo "Requesting a certificate for ${domain}..."
      if ! docker run --rm \
          -p 80:80 \
          -v "$SCRIPT_DIR/certbot/conf:/etc/letsencrypt" \
          certbot/certbot certonly \
          --standalone \
          --cert-name "$domain" \
          --email "$SSL_EMAIL" \
          --agree-tos \
          --no-eff-email \
          --non-interactive \
          -d "$domain"; then
        warn "No certificate for ${domain}."
      fi
    done
  fi
fi

for domain in "$BYTEM_DOMAIN" "$MATRIX_HOMESERVER"; do
  [ -f "certbot/conf/live/${domain}/fullchain.pem" ] || die "Certificate missing for $domain."
  [ -f "certbot/conf/live/${domain}/privkey.pem" ] || die "Private key missing for $domain."
done

# nginx adds a governance domain's server block at start, so a restart picks up
# new certificates; it also starts an edge stopped above for issuance.
if docker compose ps --all --services 2>/dev/null | grep -qx bytem-nginx; then
  docker compose restart bytem-nginx
fi

echo -e "${GREEN}TLS certificates are ready for ${domains[*]}.${NC}"

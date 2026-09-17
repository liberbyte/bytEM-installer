#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

prompt_required() {
  local variable_name=$1
  local label=$2
  local secret=${3:-false}
  local value=""

  while [ -z "$value" ]; do
    if [ "$secret" = true ]; then
      read -rsp "$label: " value
      echo
    else
      read -rp "$label: " value
    fi
  done
  printf -v "$variable_name" '%s' "$value"
}

validate_env_value() {
  local label=$1
  local value=$2
  [[ "$value" =~ ^[A-Za-z0-9._:/@%+=,-]+$ ]] || \
    die "$label contains characters that are unsafe in an environment file."
}

escape_replacement() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

replace_placeholder() {
  local placeholder=$1
  local value
  value=$(escape_replacement "$2")
  sed -i "s|\${${placeholder}}|${value}|g" "$OUTPUT_TMP"
}

existing_setting() {
  local key=$1
  if [ -f .env ]; then
    awk -v key="$key" 'index($0, key "=") == 1 {print substr($0, length(key) + 2)}' .env | tail -n 1
  fi
}

NON_INTERACTIVE=false
FORCE=false
for argument in "$@"; do
  case "$argument" in
    --non-interactive|-n) NON_INTERACTIVE=true ;;
    --force|-f) FORCE=true ;;
    *) die "Unknown option: $argument" ;;
  esac
done

if [ "$NON_INTERACTIVE" = true ]; then
  required=(DOMAIN_NAME TEST_USERNAME TEST_PASSWORD BOT_USERNAME BOT_PASSWORD)
  for variable_name in "${required[@]}"; do
    [ -n "${!variable_name:-}" ] || die "--non-interactive requires $variable_name."
  done
  SUBDOMAIN_PREFIX=${SUBDOMAIN_PREFIX:-}
else
  info "BytEM public deployment setup"
  prompt_required DOMAIN_NAME "Base domain (for example, liberbyte.app)"
  read -rp "Optional instance prefix (for example, bm4): " SUBDOMAIN_PREFIX

  echo
  info "Test/admin account (used by a person to log in and test the instance)"
  prompt_required TEST_USERNAME "Test username"
  prompt_required TEST_PASSWORD "Test password" true

  echo
  info "Bot account (used only by the backend and bot services)"
  prompt_required BOT_USERNAME "Bot username"
  prompt_required BOT_PASSWORD "Bot password" true

  echo
  info "Domain Manager (optional, Enter to skip)"
  read -rp "DEID domain repository URL (for example, https://codeberg.org/owner/repo): " DOMAIN_REPO
  read -rsp "Write token for that repository: " DOMAIN_REPO_TOKEN
  echo
fi

DOMAIN_NAME=${DOMAIN_NAME,,}
SUBDOMAIN_PREFIX=${SUBDOMAIN_PREFIX,,}
TEST_USERNAME=${TEST_USERNAME,,}
BOT_USERNAME=${BOT_USERNAME,,}

[[ "$DOMAIN_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] || \
  die "Invalid base domain: $DOMAIN_NAME"
[[ -z "$SUBDOMAIN_PREFIX" || "$SUBDOMAIN_PREFIX" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || \
  die "Invalid instance prefix: $SUBDOMAIN_PREFIX"
[[ "$TEST_USERNAME" =~ ^[a-z0-9._=-]+$ ]] || die "Invalid test username."
[[ "$BOT_USERNAME" =~ ^[a-z0-9._=-]+$ ]] || die "Invalid bot username."
[ "$TEST_USERNAME" != "$BOT_USERNAME" ] || die "Test and bot usernames must be different."

DEFAULT_DEID_DOMAIN="$DOMAIN_NAME"

for credential in TEST_PASSWORD BOT_PASSWORD; do
  validate_env_value "$credential" "${!credential}"
done

if [ -n "$SUBDOMAIN_PREFIX" ]; then
  BYTEM_DOMAIN="bytem.${SUBDOMAIN_PREFIX}.${DOMAIN_NAME}"
else
  BYTEM_DOMAIN="bytem.${DOMAIN_NAME}"
fi
MATRIX_DOMAIN="matrix.${BYTEM_DOMAIN}"

RABBITMQ_DEFAULT_USER=${RABBITMQ_DEFAULT_USER:-$(existing_setting RABBITMQ_DEFAULT_USER)}
RABBITMQ_DEFAULT_USER=${RABBITMQ_DEFAULT_USER:-bytem}
RABBITMQ_DEFAULT_PASS=${RABBITMQ_DEFAULT_PASS:-$(existing_setting RABBITMQ_DEFAULT_PASS)}
RABBITMQ_DEFAULT_PASS=${RABBITMQ_DEFAULT_PASS:-$(generate_password)}
SYNAPSE_POSTGRES_PASSWORD=${SYNAPSE_POSTGRES_PASSWORD:-$(existing_setting SYNAPSE_POSTGRES_PASSWORD)}
SYNAPSE_POSTGRES_PASSWORD=${SYNAPSE_POSTGRES_PASSWORD:-$(generate_password)}
SOLR_USER=${SOLR_USER:-$(existing_setting SOLR_USER)}
SOLR_USER=${SOLR_USER:-solr}
SOLR_PASSWORD=${SOLR_PASSWORD:-$(existing_setting SOLR_PASSWORD)}
SOLR_PASSWORD=${SOLR_PASSWORD:-$(generate_password)}
REGISTRATION_SHARED_SECRET=${REGISTRATION_SHARED_SECRET:-$(existing_setting REGISTRATION_SHARED_SECRET)}
REGISTRATION_SHARED_SECRET=${REGISTRATION_SHARED_SECRET:-$(generate_secret)}
SYNAPSE_MACAROON_SECRET_KEY=${SYNAPSE_MACAROON_SECRET_KEY:-$(existing_setting SYNAPSE_MACAROON_SECRET_KEY)}
SYNAPSE_MACAROON_SECRET_KEY=${SYNAPSE_MACAROON_SECRET_KEY:-$(generate_secret)}
SYNAPSE_FORM_SECRET=${SYNAPSE_FORM_SECRET:-$(existing_setting SYNAPSE_FORM_SECRET)}
SYNAPSE_FORM_SECRET=${SYNAPSE_FORM_SECRET:-$(generate_secret)}
JWT_SECRET=${JWT_SECRET:-$(existing_setting JWT_SECRET)}
JWT_SECRET=${JWT_SECRET:-$(generate_secret)}
MARKET_LIST=${MARKET_LIST:-$(existing_setting MARKET_LIST)}
MARKET_LIST=${MARKET_LIST:-https://bytem.app/markets/bytem-market-list.json}
# The earlier default .../byteM-market-list answers 404, which silently leaves federation off.
[ "$MARKET_LIST" != "https://bytem.app/markets/byteM-market-list" ] || MARKET_LIST=https://bytem.app/markets/bytem-market-list.json
FEDERATION_MARKET_LIST_URL=${FEDERATION_MARKET_LIST_URL:-$(existing_setting FEDERATION_MARKET_LIST_URL)}
FEDERATION_MARKET_LIST_URL=${FEDERATION_MARKET_LIST_URL:-$MARKET_LIST}
[ "$FEDERATION_MARKET_LIST_URL" != "https://bytem.app/markets/byteM-market-list" ] || FEDERATION_MARKET_LIST_URL=$MARKET_LIST
FEDERATION_EXTRA_DOMAINS=${FEDERATION_EXTRA_DOMAINS:-$(existing_setting FEDERATION_EXTRA_DOMAINS)}
FEDERATION_EXTRA_DOMAINS=${FEDERATION_EXTRA_DOMAINS:-matrix.org}
FEDERATION_STRICT=${FEDERATION_STRICT:-$(existing_setting FEDERATION_STRICT)}
FEDERATION_STRICT=${FEDERATION_STRICT:-0}
SSL_EMAIL=${SSL_EMAIL:-$(existing_setting SSL_EMAIL)}
SSL_EMAIL=${SSL_EMAIL:-admin@${BYTEM_DOMAIN}}
DOMAIN_REPO=${DOMAIN_REPO:-$(existing_setting DOMAIN_REPO)}
DOMAIN_REPO_TOKEN=${DOMAIN_REPO_TOKEN:-$(existing_setting DOMAIN_REPO_TOKEN)}
TRAFFIC_REPORT_SECRET=${TRAFFIC_REPORT_SECRET:-$(existing_setting TRAFFIC_REPORT_SECRET)}
TRAFFIC_REPORT_SECRET=${TRAFFIC_REPORT_SECRET:-$(generate_secret)}
NEXT_PUBLIC_DEMAND_PRODUCT_DEID=${NEXT_PUBLIC_DEMAND_PRODUCT_DEID:-$(existing_setting NEXT_PUBLIC_DEMAND_PRODUCT_DEID)}
NEXT_PUBLIC_DEMAND_PRODUCT_DEID=${NEXT_PUBLIC_DEMAND_PRODUCT_DEID:-https://cities.app/de/he/water/water-quality}

for variable_name in \
  RABBITMQ_DEFAULT_USER RABBITMQ_DEFAULT_PASS SYNAPSE_POSTGRES_PASSWORD \
  SOLR_USER SOLR_PASSWORD REGISTRATION_SHARED_SECRET SYNAPSE_MACAROON_SECRET_KEY \
  SYNAPSE_FORM_SECRET JWT_SECRET MARKET_LIST FEDERATION_MARKET_LIST_URL \
  FEDERATION_EXTRA_DOMAINS FEDERATION_STRICT SSL_EMAIL NEXT_PUBLIC_DEMAND_PRODUCT_DEID TRAFFIC_REPORT_SECRET; do
  validate_env_value "$variable_name" "${!variable_name}"
done
for variable_name in DOMAIN_REPO DOMAIN_REPO_TOKEN; do
  [ -z "${!variable_name:-}" ] || validate_env_value "$variable_name" "${!variable_name}"
done

if [ -f .env ]; then
  if [ "$FORCE" != true ]; then
    die ".env already exists. Re-run with --force to back it up and generate a replacement."
  fi
  backup_file=".env.backup.$(date +%Y%m%d%H%M%S)"
  cp .env "$backup_file"
  warn "Existing .env backed up to $backup_file"
fi

OUTPUT_TMP=$(mktemp .env.tmp.XXXXXX)
trap 'rm -f "$OUTPUT_TMP"' EXIT
cp .env.template "$OUTPUT_TMP"

replace_placeholder BYTEM_DOMAIN "$BYTEM_DOMAIN"
replace_placeholder MATRIX_DOMAIN "$MATRIX_DOMAIN"
replace_placeholder TEST_USERNAME "$TEST_USERNAME"
replace_placeholder TEST_PASSWORD "$TEST_PASSWORD"
replace_placeholder BOT_USERNAME "$BOT_USERNAME"
replace_placeholder BOT_PASSWORD "$BOT_PASSWORD"
replace_placeholder RABBITMQ_DEFAULT_USER "$RABBITMQ_DEFAULT_USER"
replace_placeholder RABBITMQ_DEFAULT_PASS "$RABBITMQ_DEFAULT_PASS"
replace_placeholder SYNAPSE_POSTGRES_PASSWORD "$SYNAPSE_POSTGRES_PASSWORD"
replace_placeholder SOLR_USER "$SOLR_USER"
replace_placeholder SOLR_PASSWORD "$SOLR_PASSWORD"
replace_placeholder REGISTRATION_SHARED_SECRET "$REGISTRATION_SHARED_SECRET"
replace_placeholder SYNAPSE_MACAROON_SECRET_KEY "$SYNAPSE_MACAROON_SECRET_KEY"
replace_placeholder SYNAPSE_FORM_SECRET "$SYNAPSE_FORM_SECRET"
replace_placeholder JWT_SECRET "$JWT_SECRET"
replace_placeholder MARKET_LIST "$MARKET_LIST"
replace_placeholder FEDERATION_MARKET_LIST_URL "$FEDERATION_MARKET_LIST_URL"
replace_placeholder FEDERATION_EXTRA_DOMAINS "$FEDERATION_EXTRA_DOMAINS"
replace_placeholder FEDERATION_STRICT "$FEDERATION_STRICT"
replace_placeholder SSL_EMAIL "$SSL_EMAIL"
replace_placeholder NEXT_PUBLIC_DEMAND_PRODUCT_DEID "$NEXT_PUBLIC_DEMAND_PRODUCT_DEID"
replace_placeholder DEFAULT_DEID_DOMAIN "$DEFAULT_DEID_DOMAIN"
replace_placeholder DOMAIN_REPO "${DOMAIN_REPO:-}"
replace_placeholder DOMAIN_REPO_TOKEN "${DOMAIN_REPO_TOKEN:-}"
replace_placeholder TRAFFIC_REPORT_SECRET "$TRAFFIC_REPORT_SECRET"

if grep -q '\${[A-Z_][A-Z_]*}' "$OUTPUT_TMP"; then
  grep -n '\${[A-Z_][A-Z_]*}' "$OUTPUT_TMP" >&2
  die "One or more template placeholders were not replaced."
fi

chmod 600 "$OUTPUT_TMP"
mv "$OUTPUT_TMP" .env
trap - EXIT
mkdir -p certbot/conf certbot/www logs/nginx

echo -e "${GREEN}Created .env with separate test and bot accounts.${NC}"
echo "  Application: https://${BYTEM_DOMAIN}"
echo "  Matrix:      https://${MATRIX_DOMAIN}"
echo "  Test user:   @${TEST_USERNAME}:${MATRIX_DOMAIN}"
echo "  Bot user:    @${BOT_USERNAME}:${MATRIX_DOMAIN}"
warn "Back up .env securely. Do not commit it."

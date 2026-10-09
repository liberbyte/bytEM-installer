#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./env_setup.sh [--domain de.cities.app] [--admin-user localpart|@user:matrix.de.cities.app] [--non-interactive] [--force]

Only the deployment domain and Matrix administrator are user inputs. Passwords,
service credentials and signing secrets are taken from the environment, else
kept from an existing .env, else generated, and written to .env. A rerun
therefore never rotates a secret the running stack depends on.
Two external credentials are read from the environment and cannot be generated
here:
  DOMAIN_REPO_TOKEN  write token for the DEID domain repository. Unset: the
                     deployment only reads DEIDs; DEID writes answer 503.
  STRIPE_SECRET_KEY  Stripe secret key (sk_test_... in a sandbox) for priced
                     single-click access. Unset: priced products answer 503.
SIGIL_PRIVATE_KEY (Ed25519 seed that signs exchanged data) is generated unless
set in the environment; keep the generated .env, the key is this market's identity.
The resulting public endpoints are:
  product: https://bytem.<domain>
  Matrix:  https://matrix.<domain>
EOF
}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

DEPLOYMENT_DOMAIN=${DEPLOYMENT_DOMAIN:-}
ADMIN_INPUT=${MATRIX_ADMIN_USERNAME:-}
NON_INTERACTIVE=false
FORCE=false

while (($#)); do
  case "$1" in
    --domain)
      (($# >= 2)) || fail "--domain requires a value"
      DEPLOYMENT_DOMAIN=$2
      shift 2
      ;;
    --admin-user)
      (($# >= 2)) || fail "--admin-user requires a value"
      ADMIN_INPUT=$2
      shift 2
      ;;
    --non-interactive|-n) NON_INTERACTIVE=true; shift ;;
    --force|-f) FORCE=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      if [ -z "$DEPLOYMENT_DOMAIN" ]; then
        DEPLOYMENT_DOMAIN=$1
        shift
      else
        fail "unknown argument: $1"
      fi
      ;;
  esac
done

if [ -z "$DEPLOYMENT_DOMAIN" ] && ! $NON_INTERACTIVE; then
  read -r -p "Deployment domain (for example de.cities.app): " DEPLOYMENT_DOMAIN
fi
[ -n "$DEPLOYMENT_DOMAIN" ] || fail "set --domain or DEPLOYMENT_DOMAIN"
DEPLOYMENT_DOMAIN=${DEPLOYMENT_DOMAIN,,}
DEPLOYMENT_DOMAIN=${DEPLOYMENT_DOMAIN%.}
[[ "$DEPLOYMENT_DOMAIN" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] || fail "invalid deployment domain: $DEPLOYMENT_DOMAIN"

PRODUCT_DOMAIN="bytem.${DEPLOYMENT_DOMAIN}"
MATRIX_DOMAIN="matrix.${DEPLOYMENT_DOMAIN}"
DEFAULT_DEID_DOMAIN=${DEFAULT_DEID_DOMAIN:-${DEPLOYMENT_DOMAIN#*.}}

if [ -z "$ADMIN_INPUT" ] && ! $NON_INTERACTIVE; then
  read -r -p "Matrix administrator (localpart or full MXID): " ADMIN_INPUT
fi
[ -n "$ADMIN_INPUT" ] || fail "set --admin-user or MATRIX_ADMIN_USERNAME"

if [[ "$ADMIN_INPUT" == @*:* ]]; then
  ADMIN_DOMAIN=${ADMIN_INPUT#*:}
  [ "$ADMIN_DOMAIN" = "$MATRIX_DOMAIN" ] || fail "administrator MXID must end in :$MATRIX_DOMAIN"
  ADMIN_LOCALPART=${ADMIN_INPUT#@}
  ADMIN_LOCALPART=${ADMIN_LOCALPART%%:*}
else
  ADMIN_LOCALPART=${ADMIN_INPUT#@}
fi
ADMIN_LOCALPART=${ADMIN_LOCALPART,,}
[[ "$ADMIN_LOCALPART" =~ ^[a-z0-9._=-]+$ ]] || fail "invalid Matrix administrator localpart: $ADMIN_LOCALPART"
ADMIN_MXID="@${ADMIN_LOCALPART}:${MATRIX_DOMAIN}"

random_hex() {
  local bytes=$1
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
  fi
}

# Environment first, then the existing .env, then the default. Postgres keeps the
# password it was initialised with and SIGIL_PRIVATE_KEY is the market's signing
# identity, so a rerun must not replace them.
existing() {
  if [ -f .env ]; then
    awk -v k="$1" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' .env
  fi
}
keep() {
  local value=${!1:-}
  [ -n "$value" ] || value=$(existing "$1")
  [ -n "$value" ] || value=$2
  printf -v "$1" '%s' "$value"
}

keep BOT_PASSWORD "$(random_hex 16)"
keep MATRIX_ADMIN_PASSWORD "$(random_hex 12)"
keep RABBITMQ_DEFAULT_USER bytem
keep RABBITMQ_DEFAULT_PASS "$(random_hex 24)"
keep POSTGRES_PASSWORD "$(random_hex 24)"
keep SYNAPSE_MACAROON_SECRET_KEY "$(random_hex 32)"
keep JWT_SECRET "$(random_hex 32)"
keep TRAFFIC_REPORT_SECRET "$(random_hex 16)"
# .env is read by `source` (install.sh) and by compose: no quotes, spaces, $ or backslashes.
for name in BOT_PASSWORD MATRIX_ADMIN_PASSWORD; do
  [[ "${!name}" =~ ^[A-Za-z0-9._~@%+=,:#!-]+$ ]] || fail "$name may only contain letters, digits and . _ ~ @ % + = , : # ! -"
done
MARKET_LIST=${MARKET_LIST:-https://bytem.app/markets/bytem-market-list.json}
FEDERATION_MARKET_LIST_URL=${FEDERATION_MARKET_LIST_URL:-$MARKET_LIST}
SSL_EMAIL=${SSL_EMAIL:-admin@${DEPLOYMENT_DOMAIN}}
keep DOMAIN_REPO_TOKEN ""
keep SIGIL_PRIVATE_KEY "$(random_hex 32)"
[[ "$SIGIL_PRIVATE_KEY" =~ ^[0-9a-fA-F]{64}$ ]] || fail "SIGIL_PRIVATE_KEY must be 64 hex characters (a 32-byte Ed25519 seed)"
keep STRIPE_SECRET_KEY ""

TEMPLATE=.env.template
OUTPUT=.env
[ -f "$TEMPLATE" ] || fail "$TEMPLATE was not found; run this from the repository root"

if [ -e "$OUTPUT" ]; then
  if ! $FORCE; then
    if $NON_INTERACTIVE; then
      fail "$OUTPUT exists; rerun with --force to back it up and replace it"
    fi
    read -r -p ".env exists. Back it up and replace it? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { info "No changes made."; exit 0; }
  fi
  backup=".env.backup.$(date -u +%Y%m%dT%H%M%SZ)"
  cp -p "$OUTPUT" "$backup"
  chmod 600 "$backup"
  info "Backed up the existing environment to $backup"
fi

tmp=$(mktemp ./.env.tmp.XXXXXX)
trap 'rm -f "$tmp"' EXIT
chmod 600 "$tmp"

while IFS= read -r line || [ -n "$line" ]; do
  line=${line//@DEPLOYMENT_DOMAIN@/$DEPLOYMENT_DOMAIN}
  line=${line//@PRODUCT_DOMAIN@/$PRODUCT_DOMAIN}
  line=${line//@MATRIX_DOMAIN@/$MATRIX_DOMAIN}
  line=${line//@DEFAULT_DEID_DOMAIN@/$DEFAULT_DEID_DOMAIN}
  line=${line//@ADMIN_LOCALPART@/$ADMIN_LOCALPART}
  line=${line//@ADMIN_MXID@/$ADMIN_MXID}
  line=${line//@MATRIX_ADMIN_PASSWORD@/$MATRIX_ADMIN_PASSWORD}
  line=${line//@BOT_PASSWORD@/$BOT_PASSWORD}
  line=${line//@RABBITMQ_DEFAULT_USER@/$RABBITMQ_DEFAULT_USER}
  line=${line//@RABBITMQ_DEFAULT_PASS@/$RABBITMQ_DEFAULT_PASS}
  line=${line//@POSTGRES_PASSWORD@/$POSTGRES_PASSWORD}
  line=${line//@SYNAPSE_MACAROON_SECRET_KEY@/$SYNAPSE_MACAROON_SECRET_KEY}
  line=${line//@JWT_SECRET@/$JWT_SECRET}
  line=${line//@MARKET_LIST@/$MARKET_LIST}
  line=${line//@FEDERATION_MARKET_LIST_URL@/$FEDERATION_MARKET_LIST_URL}
  line=${line//@SSL_EMAIL@/$SSL_EMAIL}
  line=${line//@DOMAIN_REPO_TOKEN@/$DOMAIN_REPO_TOKEN}
  line=${line//@SIGIL_PRIVATE_KEY@/$SIGIL_PRIVATE_KEY}
  line=${line//@STRIPE_SECRET_KEY@/$STRIPE_SECRET_KEY}
  line=${line//@TRAFFIC_REPORT_SECRET@/$TRAFFIC_REPORT_SECRET}
  printf '%s\n' "$line" >> "$tmp"
done < "$TEMPLATE"

if grep -Eq '@[A-Z][A-Z0-9_]+@' "$tmp"; then
  fail "unresolved template values remain in generated environment"
fi
mv -f "$tmp" "$OUTPUT"
trap - EXIT
chmod 600 "$OUTPUT"

info "Environment ready:"
info "  identity: $DEPLOYMENT_DOMAIN"
info "  product:  https://$PRODUCT_DOMAIN"
info "  Matrix:   https://$MATRIX_DOMAIN"
info "  admin:    $ADMIN_MXID"
info "Secrets are in .env and were not printed; the administrator password is MATRIX_ADMIN_PASSWORD there. Keep that file private."
[ -n "$DOMAIN_REPO_TOKEN" ] || info "DOMAIN_REPO_TOKEN is empty: DEID writes will answer 503 until it is set in .env."
[ -n "$STRIPE_SECRET_KEY" ] || info "STRIPE_SECRET_KEY is empty: priced products will answer 503 until it is set in .env."

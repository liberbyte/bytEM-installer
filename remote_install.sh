#!/usr/bin/env bash
# Installs or upgrades bytEM on this server, run over ssh by the command that
# install.html composes. Its one argument is the wizard's values as base64 of
# KEY=VALUE lines, which keeps the command the same in PowerShell and bash.
#
# Where it works:
#   - the folder of the running bytem-nginx container (Compose labels it), else
#   - ~/bytEM when it exists, else
#   - a fresh clone of this repository into ~/bytEM.
# A folder whose docker-compose.yaml builds images is a checkout of the bytEM
# source: it is pulled and rebuilt. Any other is an installer clone: it is pulled
# and install.sh pulls the published images. Volumes, .env and certificates stay.
set -euo pipefail
trap 'rm -f "$0"' EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }

REPO=https://github.com/liberbyte/bytEM-installer.git
TARGET="$HOME/bytEM"

(($# == 1)) || die "usage: remote_install.sh <wizard values, base64>"
DOMAIN=
ADMIN_USER=
SSH_HOST=
FORCE_RECREATE=
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  key=${line%%=*}
  value=${line#*=}
  case "$key" in
    DOMAIN|ADMIN_USER|SSH_HOST|FORCE_RECREATE) printf -v "$key" '%s' "$value" ;;
    # Read by env_setup.sh from its environment.
    ADMIN_PASSWORD|SSL_EMAIL|DOMAIN_REPO_TOKEN|STRIPE_SECRET_KEY|SIGIL_PRIVATE_KEY) export "$key=$value" ;;
    *) die "unknown wizard value: $key" ;;
  esac
done < <(printf '%s' "$1" | base64 -d)
[ -n "$DOMAIN" ] && [ -n "$ADMIN_USER" ] || die "the wizard values lack DOMAIN or ADMIN_USER"

if [ "$(id -u)" -eq 0 ]; then SUDO=(); else SUDO=(sudo); fi

# The value of KEY in an .env file, empty when absent.
env_value() {
  if [ -f "$1" ]; then
    awk -v k="$2" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' "$1"
  fi
}

log "Checking the server"
if ! command -v git >/dev/null 2>&1; then
  command -v apt-get >/dev/null 2>&1 || die "git is missing; install it and run the command again."
  log "Installing git"
  "${SUDO[@]}" apt-get update -qq
  "${SUDO[@]}" apt-get install -y -qq git
fi

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine"
  curl -fsSL https://get.docker.com | "${SUDO[@]}" sh
fi

if ! docker info >/dev/null 2>&1; then
  "${SUDO[@]}" systemctl enable --now docker >/dev/null 2>&1 || true
  if ! docker info >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ] || id -nG | grep -qw docker; then
      die "Docker does not answer: $(docker info 2>&1 | tail -n 1)"
    fi
    # Group membership reaches new logins only; sg gives it to this run.
    log "Adding $USER to the docker group"
    "${SUDO[@]}" usermod -aG docker "$USER"
    trap - EXIT
    exec sg docker -c "bash $(printf '%q' "$0") $(printf '%q' "$1")"
  fi
fi

if ! docker compose version >/dev/null 2>&1; then
  log "Installing the Docker Compose plugin"
  "${SUDO[@]}" apt-get install -y -qq docker-compose-plugin 2>/dev/null || \
    "${SUDO[@]}" apt-get install -y -qq docker-compose-v2 || \
    die "the Docker Compose plugin could not be installed."
fi

running=$(docker inspect bytem-nginx \
  --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null || true)
if [ -n "$running" ]; then
  DIR=$running
  log "bytEM is running from $DIR"
else
  # Without a bytEM container, anything on these ports (another web server, a
  # k3s deployment of bytEM) would take the edge's place.
  busy=$(ss -Hltn '( sport = :80 or sport = :443 or sport = :8448 )' 2>/dev/null || true)
  [ -z "$busy" ] || die "ports 80, 443 or 8448 are taken by something that is not a bytEM container:
$busy"
  if [ -e "$TARGET" ]; then
    DIR=$TARGET
    log "Found $DIR"
  else
    DIR=
  fi
fi

if [ -n "$DIR" ]; then
  [ -f "$DIR/docker-compose.yaml" ] || die "$DIR has no docker-compose.yaml; it is not a bytEM folder."
  existing_domain=$(env_value "$DIR/.env" DOMAIN_NAME)
  [ -z "$existing_domain" ] || [ "$existing_domain" = "$DOMAIN" ] || \
    die "$DIR is the market for $existing_domain, not $DOMAIN. Enter $existing_domain in the wizard to upgrade it."
fi

if [ -n "$DIR" ] && grep -Eq '^[[:space:]]+build:' "$DIR/docker-compose.yaml"; then
  log "Source checkout: pulling the code and rebuilding the images"
  git -C "$DIR" pull --ff-only
  git -C "$DIR" submodule update --init --recursive
  cd "$DIR"
  docker compose up -d --build --force-recreate
  docker compose ps
  echo -e "${GREEN}bytEM is rebuilt from $(git rev-parse --short HEAD) in $DIR.${NC}"
  exit 0
fi

if [ -z "$DIR" ]; then
  DIR=$TARGET
  log "Installing into $DIR"
  git clone -q "$REPO" "$DIR"
else
  [ -f "$DIR/install.sh" ] && [ -f "$DIR/env_setup.sh" ] || die "$DIR is neither a bytEM source checkout nor an installer clone."
  log "Updating the installer in $DIR"
  git -C "$DIR" pull --ff-only
fi
cd "$DIR"
chmod +x env_setup.sh certbot.sh install.sh whitelist-sync.sh scripts/*.sh

if [ -f .env ]; then
  log "Keeping the existing .env"
else
  ./env_setup.sh --domain "$DOMAIN" --admin-user "$ADMIN_USER" --non-interactive
  # Let's Encrypt fails when a name points elsewhere; say so before it tries.
  addresses=" $(hostname -I 2>/dev/null) "
  points_here() {
    local ip
    for ip in $1; do [[ "$addresses" == *" $ip "* ]] && return 0; done
    return 1
  }
  for name in "bytem.$DOMAIN" "matrix.$DOMAIN"; do
    resolved=$(getent ahosts "$name" | awk '{ print $1 }' | sort -u | paste -sd ' ' || true)
    if [ -z "$resolved" ]; then
      warn "$name does not resolve; its certificate will fail until DNS points it to this server."
    elif ! points_here "$resolved"; then
      warn "$name resolves to $resolved, which is not an address of this server (behind NAT this is expected)."
    fi
  done
fi

if [ -n "$FORCE_RECREATE" ]; then
  ./install.sh --force-recreate
else
  ./install.sh
fi

echo
echo "  Folder:         $DIR"
echo "  Admin password: $(env_value .env ADMIN_PASSWORD)"
echo "  Keep a copy of .env; it holds every credential and the signing key. From your computer:"
echo "    scp ${USER}@${SSH_HOST:-<this server>}:${DIR}/.env bytem-${DOMAIN}.env"

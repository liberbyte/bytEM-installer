# bytEM installer 

This repository installs bytEM from the Docker images published by the main
repository's GitHub Actions workflow. It does not build application source.

The current stack has one frontend: `bytem-pwa`. The retired `bytem-app`
container is replaced by `bytem-nginx`, which provides TLS, reverse proxying,
Matrix discovery, and federation.

## Install

Requirements:

- Linux host with Docker Engine and the `docker compose` plugin
- DNS records for both generated hostnames pointing to the host
- inbound TCP ports 80, 443, and 8448

```bash
git clone https://github.com/liberbyte/bytEM-public.git
cd bytEM-public
chmod +x env_setup.sh certbot.sh install.sh whitelist-sync.sh scripts/*.sh
./env_setup.sh
./install.sh
```

`env_setup.sh` asks for two distinct accounts:

- a test/admin username and password for interactive login
- a bot username and password for the backend services

Do not reuse one account's credentials for the other. The bot and backend log
in and refresh their bot access token at runtime; no access token needs to be
copied into `.env`.

For unattended configuration, supply the required variables explicitly:

```bash
DOMAIN_NAME=example.com \
SUBDOMAIN_PREFIX=bm4 \
TEST_USERNAME=test \
TEST_PASSWORD='test-secret' \
BOT_USERNAME=bot \
BOT_PASSWORD='bot-secret' \
./env_setup.sh --non-interactive
```

See [BYTEM_INSTALL.md](BYTEM_INSTALL.md) for upgrades, TLS, verification, and
troubleshooting. Keep `.env`, `certbot/`, and all `bytem-*` Docker volumes backed
up; they contain credentials and persistent service data.

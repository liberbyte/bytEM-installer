# bytEM installer 

This repository installs bytEM from the Docker images published by the main
repository's GitHub Actions workflow. It does not build application source.

## Install

Requirements:

- Linux host with Docker Engine and the `docker compose` plugin
- DNS records for `bytem.<domain>` and `matrix.<domain>` pointing to the host
- inbound TCP ports 80, 443, and 8448

```bash
git clone https://github.com/liberbyte/bytEM-installer.git
cd bytEM-installer
chmod +x env_setup.sh certbot.sh install.sh whitelist-sync.sh scripts/*.sh
./env_setup.sh --domain de.example.org --admin-user admin
./install.sh
```

`env_setup.sh` asks only for the deployment domain and the Matrix administrator.
For `de.example.org` the application is `https://bytem.de.example.org` and
Matrix is `https://matrix.de.example.org`. Passwords, database and queue
credentials, signing keys and the traffic-report secret are generated into
`.env`; the administrator password is `MATRIX_ADMIN_PASSWORD` there. The bot
account is `bot`; the services log in with it themselves.

Optional values are read from the environment of the same command:

```bash
 MATRIX_ADMIN_PASSWORD='choose-one' DOMAIN_REPO_TOKEN='...' STRIPE_SECRET_KEY='sk_test_...' \
  ./env_setup.sh --domain de.example.org --admin-user admin --non-interactive
```

| Variable | Without it |
|---|---|
| `MATRIX_ADMIN_PASSWORD` | generated |
| `SSL_EMAIL` | `admin@<domain>` |
| `DOMAIN_REPO_TOKEN` | DEIDs are read-only; DEID writes answer 503 |
| `STRIPE_SECRET_KEY` | priced products answer 503 |
| `SIGIL_PRIVATE_KEY` | generated; this key is the market's signing identity |

Passwords may contain letters, digits and `. _ ~ @ % + = , : # ! -`.

`install.html` is a page that builds the same command from a form.

## Upgrade

Keep `.env` and run `./install.sh`; it pulls the published images and recreates
the containers. Re-running `env_setup.sh --force` keeps every existing secret
in `.env` (it reads them back) and backs up the old file first.

See [BYTEM_INSTALL.md](BYTEM_INSTALL.md) for TLS, verification, and
troubleshooting. Keep `.env`, `certbot/`, and all `bytem-*` Docker volumes backed
up; they contain credentials and persistent service data.

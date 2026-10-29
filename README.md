# bytEM installer 

This repository installs bytEM from the Docker images published by the main
repository's GitHub Actions workflow. It does not build application source.

## Install

Requirements:

- Linux host reachable over SSH; Docker Engine and the `docker compose` plugin
  are installed when missing (Debian or Ubuntu, with sudo)
- DNS records for `bytem.<domain>` and `matrix.<domain>` pointing to the host
- inbound TCP ports 80, 443, and 8448

### From your computer

Open `install.html` in a browser (download the file from this repository and
double-click it). It asks for the server address, the SSH user, the deployment
domain and the administrator, and prints one command for Windows PowerShell or
a Linux terminal:

```text
ssh -t ubuntu@bytem.de.example.org "curl -fsSL https://raw.githubusercontent.com/liberbyte/bytEM-installer/main/remote_install.sh -o ~/.bytem-remote-install.sh && bash ~/.bytem-remote-install.sh RE9NQUlO…"
```

SSH asks for the password when no key is set up, and sudo asks for its password
when Docker or git has to be installed. `remote_install.sh` then works in:

- the folder the running `bytem-nginx` container was started from, else
- `~/bytEM` when it exists, else
- a fresh clone of this repository into `~/bytEM`.

An installer folder is updated with `git pull`; `.env` is written by
`env_setup.sh` only when missing, and `install.sh` pulls the published images.
A checkout of the bytEM source (its `docker-compose.yaml` builds images) is
updated with `git pull` and `git submodule update --init --recursive`, then
rebuilt with `docker compose up -d --build --force-recreate`. A folder whose
`.env` names another deployment domain is left alone. Without a running stack,
the command stops when ports 80, 443 or 8448 are taken. Volumes, `.env` and
certificates are kept in every case.

### On the server

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
`.env`; the administrator password is `ADMIN_PASSWORD` there. The bot
account is `bot`; the services log in with it themselves.

Optional values are read from the environment of the same command:

```bash
 ADMIN_PASSWORD='choose-one' DOMAIN_REPO_TOKEN='...' STRIPE_SECRET_KEY='sk_test_...' \
  ./env_setup.sh --domain de.example.org --admin-user admin --non-interactive
```

| Variable | Without it |
|---|---|
| `ADMIN_PASSWORD` | generated |
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

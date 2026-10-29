# bytEM Installation and Upgrade Guide

## Installation Video

The following video provides a step-by-step demonstration of the bytEM installation process.

https://github.com/user-attachments/assets/ee724e7d-fe32-400e-9641-5219ec5bab41

## Architecture

The public installer pulls the images produced by the private/source repository's GitHub Actions workflow:

| Service         | Image                          | Purpose                                             |
| --------------- | ------------------------------ | --------------------------------------------------- |
| `bytem-nginx`   | `liberbyteadmin/bytem:nginx`   | TLS, reverse proxy, Matrix discovery and federation |
| `bytem-pwa`     | `liberbyteadmin/bytem:pwa`     | The single merged frontend                          |
| `bytem-be`      | `liberbyteadmin/bytem:be`      | API gateway                                         |
| `bytem-bot`     | `liberbyteadmin/bytem:bot`     | Matrix workflow bot                                 |
| `bytem-synapse` | `liberbyteadmin/bytem:synapse` | Matrix Synapse with bytEM modules                   |
| `bytem-solr`    | `liberbyteadmin/bytem:solr`    | Search index                                        |

PostgreSQL and RabbitMQ use their upstream images.

There is no `bytem-app` service and no generated host-side nginx or Synapse configuration. The nginx and Synapse images generate their configuration from `.env`. Synapse data, including its signing key and media, lives in the `bytem-synapse-data` volume.

---

## Prerequisites

Before installing bytEM, make sure the following requirements are available:

* Docker Engine with Compose v2
* At least 8 GB RAM available for the Synapse container limit
* DNS A/AAAA records for the application and Matrix names
* Inbound TCP ports `80`, `443`, and `8448`
* Outbound HTTPS access for Docker image pulls and federation market-list retrieval


### Install Docker if not already installed

If Docker is not installed on the server, install Docker Engine and Docker Compose v2 before continuing with the bytEM installation.

Run:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo systemctl status docker
```

Verify that Docker and Docker Compose are available:

```bash
docker --version
docker compose version
```

If Docker is running correctly, continue with the bytEM installation.


### Docker permissions

The installer uses Docker commands. If your user does not have permission to access the Docker socket, you may see an error similar to:

```text
permission denied while trying to connect to the Docker daemon socket
```

You can either run the installer with `sudo`:

```bash
sudo ./install.sh
```

Or add your user to the Docker group:

```bash
sudo usermod -aG docker $USER
```

After running this command, log out and log back in before using Docker without `sudo`.

Verify that Docker works:

```bash
docker ps
```

> [!NOTE]
> Membership in the `docker` group provides privileged access to the Docker daemon.

For the deployment domain `de.example.org`, setup creates:

* `bytem.de.example.org` (application)
* `matrix.de.example.org` (Matrix)

Both names must resolve to the Docker host before certificate issuance.

---

# Fresh Installation

## From your computer

Download `install.html` from this repository and open it in a browser; it makes no network calls. Fill in:

* the server address (IP or host name; empty means `bytem.<deployment domain>`) and the SSH user,
* the deployment domain, the administrator and the optional credentials.

The last step prints one command. Paste it into Windows PowerShell or a Linux terminal:

```text
ssh -t ubuntu@bytem.de.example.org "curl -fsSL https://raw.githubusercontent.com/liberbyte/bytEM-installer/main/remote_install.sh -o ~/.bytem-remote-install.sh && bash ~/.bytem-remote-install.sh RE9NQUlO…"
```

`ssh -t` gives the server a terminal, so SSH asks for the password when no key is set up and sudo asks for its own when something has to be installed. The last word is the wizard's values, base64-encoded. On the server, `remote_install.sh`:

1. Installs git, Docker Engine (from `get.docker.com`) and the Compose plugin when missing, and adds the SSH user to the `docker` group.
2. Finds an existing bytEM: the folder the running `bytem-nginx` container was started from, else `~/bytEM`. Without either, it stops when ports 80, 443 or 8448 are taken, and otherwise clones this repository into `~/bytEM`.
3. Stops when that folder's `.env` names another deployment domain.
4. In an installer folder: `git pull`, `env_setup.sh` only when `.env` is missing, then `install.sh` (with `--force-recreate` when ticked in the wizard).
5. In a checkout of the bytEM source (its `docker-compose.yaml` builds images): `git pull`, `git submodule update --init --recursive` and `docker compose up -d --build --force-recreate`.
6. Prints the folder, the administrator password and an `scp` command that copies `.env` to your computer.

Volumes, `.env` and certificates are kept in every case. The same command upgrades a server later.

## On the server

```bash
git clone https://github.com/liberbyte/bytEM-installer.git
cd bytEM-installer
chmod +x env_setup.sh certbot.sh install.sh whitelist-sync.sh scripts/*.sh
```

`install.html` also prints the `env_setup.sh` command for this case. Run it; it writes `.env`. Then run the installer.

If Docker is configured for your user:

```bash
./install.sh
```

If you receive a Docker socket permission error, either configure Docker group access as described in the prerequisites or run:

```bash
sudo ./install.sh
```

The installer:

1. Validates the configuration.
2. Pulls the published Docker images.
3. Obtains missing TLS certificates, for the two bytEM names and every governance domain in `domain_files/<domain>/`.
4. Migrates legacy Synapse `/data`, when present.
5. Starts the Docker stack (`./install.sh --force-recreate` recreates every container).
6. Waits for the required health checks.

---

## Alternative: Command-Line Configuration

For headless servers or environments without a browser, use:

```bash
./env_setup.sh --domain de.example.org --admin-user admin
```

Then run:

```bash
./install.sh
```

If Docker permissions are not configured for your user:

```bash
sudo ./install.sh
```

The `env_setup.sh` script remains the supported command-line and headless installation path.

---

# Account Credentials

## Administrator

The administrator is the account a person uses to sign in. `--admin-user` sets its name. Its password is `ADMIN_PASSWORD` in `.env`: generated unless you pass one in the environment of `env_setup.sh`.

## Bot

The bot account `bot` is used by `bytem-be` and `bytem-bot` only. Its password `BOT_PASSWORD` is generated; nobody signs in with it.

Synapse creates both accounts on first start. A password changed later in `.env` does not change the account: sign in and use **Password** in the application header, then put the new value in `.env` too, or `scripts/test_workflow.sh` can no longer sign in.

Every other secret (PostgreSQL, RabbitMQ, Synapse macaroon, JWT, SIGIL signing key, traffic-report secret) is generated into `.env`. Re-running `env_setup.sh` keeps them. Store `.env` in a password manager or secure backup and never commit it.

# Password Requirements

`env_setup.sh` accepts passwords made of letters, digits and `. _ ~ @ % + = , : # ! -`. Other characters (spaces, quotes, `$`, backslashes) are rejected, because `.env` is read by the shell and by Docker Compose.

---

# TLS

`install.sh` calls `certbot.sh` automatically when a certificate is missing: for `BYTEM_DOMAIN`, `MATRIX_HOMESERVER` or a governance domain in `domain_files/<domain>/`. nginx serves a governance domain once its certificate exists.

For certificate renewal:

```bash
./certbot.sh
```

For local-only testing where public Let's Encrypt validation is impossible:

```bash
./certbot.sh --self-signed
./install.sh
```

If your Docker installation requires `sudo`, use:

```bash
sudo ./certbot.sh --self-signed
sudo ./install.sh
```

Self-signed certificates cause browser warnings and are not suitable for Matrix federation in production.

---

# Upgrade an Existing Installation

Back up the existing state first:

```bash
./scripts/pre_reinstall_check.sh
cp .env "/secure/location/bytem.env.$(date +%F)"
```

Then update the repository:

```bash
git pull --ff-only
```

Run the installer:

```bash
./install.sh
```

If Docker permissions are not configured for your user:

```bash
sudo ./install.sh
```

The installer does not run `docker compose down -v`, prune all images, replace `.env`, or delete certificates.

The existing PostgreSQL, Solr, RabbitMQ, and Synapse named volumes are retained.

When upgrading from the old `bytem-app` Compose layout, the installer detects:

```text
generated_config_files/synapse_config
```

If the new `bytem-synapse-data` volume is empty, it copies the old `/data` contents into that volume before starting Synapse. This preserves the server signing key and media.

The old `generated_config_files` directory is not deleted automatically. Remove it only after verifying the upgraded deployment and retaining a backup.

An `.env` written by an earlier installer version lacks variables the current images read (for example `SIGIL_PRIVATE_KEY`, `STRIPE_SECRET_KEY`, `BOT_USERS`). Regenerate it from the current template; existing secrets are read back from the old file:

```bash
./env_setup.sh --domain <your deployment domain> --admin-user <existing admin> --force
```

The old file is kept as `.env.backup.<time>`. Compare the two before running `./install.sh`.

> [!WARNING]
> Changing Synapse secrets or losing its signing key can invalidate sessions or break federation identity. Do not regenerate these values during a routine image upgrade.

---

# Verification and Operation

Check that all services are running:

```bash
docker compose ps
```

Check the main service logs:

```bash
docker compose logs --tail 100 bytem-synapse bytem-be bytem-bot bytem-nginx
```

Load the environment variables:

```bash
set -a
source .env
set +a
```

Check the backend:

```bash
curl -fsS "https://${BYTEM_DOMAIN}/api/auth/health"
```

Check the Matrix server:

```bash
curl -fsS "https://${MATRIX_HOMESERVER}/_matrix/client/versions"
```

Run the end-to-end workflow test:

```bash
./scripts/test_workflow.sh
```

The test account and bot account remain separate:

* The test account logs in and creates the test rooms.
* The bot is invited to process them.

Synapse builds its federation whitelist at container start from `FEDERATION_MARKET_LIST_URL` (or `MARKET_LIST`).

To fetch it again and inspect the resulting active list:

```bash
./whitelist-sync.sh
```

## Domain explorer

Admins open **Domain explorer** on the Overview page to browse, edit and delete the DEID documents of `DEFAULT_DEID_DOMAIN`. It works on the repository in `.env` (`DOMAIN_REPO` is preset by the template; `DOMAIN_REPO_TOKEN` comes from the environment of `env_setup.sh`):

```text
DOMAIN_REPO=https://codeberg.org/owner/repo
DOMAIN_REPO_TOKEN=<Forgejo/Gitea access token with write access to that repository>
```

Without `DOMAIN_REPO` the explorer is unavailable; without `DOMAIN_REPO_TOKEN` it can browse but not save. Restart `bytem-be` after changing either value.

## Access log and traffic report

`bytem-nginx` writes the public site's access log, with client IPs truncated, to `logs/nginx/access.log`. To turn it into a report (needs `goaccess` on the host):

```bash
goaccess logs/nginx/access.log --log-format='%h - %^ [%d:%t %^] "%r" %s %b "%R" "%u" %T %^' \
  --date-format=%d/%b/%Y --time-format=%T -o logs/nginx/traffic-report.html
```

Share it as `https://${BYTEM_DOMAIN}/traffic-report.html?secret=${TRAFFIC_REPORT_SECRET}`. Change `TRAFFIC_REPORT_SECRET` in `.env` and restart `bytem-nginx` to revoke every shared link.

---

# Common Problems

| Symptom                           | Solution                                                                                                                             |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Docker socket permission denied   | Add your user to the Docker group using `sudo usermod -aG docker $USER`, log in again, or run the installer with `sudo ./install.sh` |
| Password is rejected during setup | Use letters, digits and `. _ ~ @ % + = , : # ! -` only                                                                               |
| nginx repeatedly restarts         | Verify both certificate paths exist under `certbot/conf/live/`; run `./certbot.sh`                                                   |
| Let's Encrypt validation fails    | Verify both DNS names point to this server, port `80` is open, and no unrelated process occupies the port                            |
| bot/backend exits after startup   | Verify `BOT_USERNAME` and `BOT_PASSWORD` match the separate bot account                                                              |
| admin login fails                 | Use `ADMIN_USERNAME` and `ADMIN_PASSWORD` from `.env`, not the bot credentials                                         |
| Synapse cannot start              | Run `docker compose logs bytem-synapse bytem-synapse-db` and verify stable secrets in `.env`                                         |
| cross-instance exchange fails     | Run `./whitelist-sync.sh` and check market-list reachability                                                                         |
| old `/pwa/...` bookmark           | nginx redirects it to the equivalent root PWA route                                                                                  |

---

# Recommended Installation Flow

```text
Open install.html on your computer
        ↓
Complete the wizard
        ↓
Paste the printed ssh command into PowerShell or a terminal
        ↓
Verify installation
```

`env_setup.sh` and `install.sh` on the server remain available for command-line and headless installations.

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

For a base domain `example.com` and prefix `bm4`, setup creates:

* `bytem.bm4.example.com`
* `matrix.bytem.bm4.example.com`

Both names must resolve to the Docker host before certificate issuance.

---

# Fresh Installation

## 1. Clone the repository

```bash
git clone https://github.com/liberbyte/bytEM-public.git
cd bytEM-public
chmod +x env_setup.sh certbot.sh install.sh whitelist-sync.sh scripts/*.sh
```

## 2. Configure bytEM using the GUI wizard

The easiest way to configure a new bytEM installation is to use the graphical installation wizard:

```text
install.html
```

### Serve the wizard locally

Serve the repository directory locally:

```bash
python3 -m http.server 8080 --bind 127.0.0.1
```

Then open the installation wizard in your browser:

```text
http://127.0.0.1:8080/install.html
```

> [!NOTE]
> Serving `install.html` through a local HTTP server is the recommended method.

Alternatively, if direct file access is supported in your environment, on Linux you can open it with:

```bash
xdg-open install.html
```

The GUI wizard guides you through the installation configuration and creates the required `.env` configuration.

The wizard includes configuration for:

1. Domains
2. Test/admin account credentials
3. Bot account credentials
4. Federation and TLS settings

After completing the wizard, continue with the installation.

## 3. Run the installer

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
3. Obtains missing TLS certificates.
4. Migrates legacy Synapse `/data`, when present.
5. Starts the Docker stack.
6. Waits for the required health checks.

---

## Alternative: Command-Line Configuration

For headless servers or environments without a browser, use:

```bash
./env_setup.sh
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

The setup requires two separate accounts.

## Test/admin account

The test/admin account is used by a person to sign in and exercise the bytEM instance.

Example:

```text
TEST_USERNAME=test
TEST_PASSWORD=your-password
```

## Bot account

The bot account is used internally by `bytem-be` and `bytem-bot`.

Example:

```text
BOT_USERNAME=bot
BOT_PASSWORD=your-bot-password
```

Nobody should normally sign in manually using the bot account.

The usernames must be different, and the test/admin and bot accounts should use different passwords.

Synapse creates both accounts during the initial installation.

Infrastructure passwords and stable Synapse secrets are generated automatically. Store `.env` in a password manager or secure backup and never commit it.

---

# Password Requirements

Passwords are validated by the installation scripts and GUI wizard.

Passwords may contain:

* Letters
* Numbers
* Only the special characters explicitly supported by the installation wizard

> [!IMPORTANT]
> Do not use unsupported special characters in installation passwords. For example, `#` is not supported and may cause the password to be rejected.

Use only the characters permitted by the GUI wizard or `env_setup.sh`.

If a password is rejected during setup, create a new password using only letters, numbers, and the supported special characters.

---

# TLS

`install.sh` calls `certbot.sh` automatically when either certificate is missing.

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

If you intentionally need a replacement `.env`, use:

```bash
./env_setup.sh --force
```

This is also the migration path for an old `.env` that used the bot as its test admin. Enter the existing domains plus new, separate account credentials.

The script preserves existing database/search passwords and stable Synapse secrets unless you explicitly override those values.

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
curl -fsS "https://${DOMAIN_NAME}/api/auth/health"
```

Check the Matrix server:

```bash
curl -fsS "https://${MATRIX_SERVER_NAME}/_matrix/client/versions"
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

---

# Common Problems

| Symptom                           | Solution                                                                                                                             |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Docker socket permission denied   | Add your user to the Docker group using `sudo usermod -aG docker $USER`, log in again, or run the installer with `sudo ./install.sh` |
| Password is rejected during setup | Use letters, numbers, and only the special characters supported by the installer. Do not use unsupported characters such as `#`      |
| nginx repeatedly restarts         | Verify both certificate paths exist under `certbot/conf/live/`; run `./certbot.sh`                                                   |
| Let's Encrypt validation fails    | Verify both DNS names point to this server, port `80` is open, and no unrelated process occupies the port                            |
| bot/backend exits after startup   | Verify `BOT_USERNAME` and `BOT_PASSWORD` match the separate bot account                                                              |
| test login fails                  | Use `TEST_USERNAME` and `TEST_PASSWORD`, not the bot credentials                                                                     |
| Synapse cannot start              | Run `docker compose logs bytem-synapse bytem-synapse-db` and verify stable secrets in `.env`                                         |
| cross-instance exchange fails     | Run `./whitelist-sync.sh` and check market-list reachability                                                                         |
| old `/pwa/...` bookmark           | nginx redirects it to the equivalent root PWA route                                                                                  |

---

# Recommended Installation Flow

```text
Clone repository
        ↓
Start local web server
        ↓
Open install.html
        ↓
Complete GUI wizard
        ↓
Run ./install.sh
        ↓
Verify installation
```

The GUI wizard is the recommended installation method for users with browser access. `env_setup.sh` remains available for command-line and headless installations.

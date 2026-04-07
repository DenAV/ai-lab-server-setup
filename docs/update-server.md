# Updating the AI Lab Server

How to apply changes from the `ai-lab-server-setup` repository to a running
server. Use this after pushing improvements to GitHub.

## When to Update

- New services added to `docker-compose.yml`
- Service versions bumped (Dify, n8n, Flowise, etc.)
- Configuration changes (`docker-compose.yml`, `config/`, scripts)
- New demo project support (`.env.example` changes)
- Security patches or hardening improvements

## Update Procedure

### Step 1: Push Changes to GitHub

From your local machine:

```bash
cd ai-lab-server-setup
git add -A
git commit -m "feat(compose): add demo-db service"
git push origin main
```

### Step 2: Pull on the Server

```bash
ssh lab@<server-ip>
cd ~/ai-lab-server-setup
git pull
```

### Step 3: Apply Changes

The type of change determines the commands needed:

#### Docker Compose changes (new services, version bumps, env vars)

```bash
# Preview what will change
docker compose pull        # pull new images (if versions bumped)
docker compose up -d       # recreate only changed services
```

Docker Compose automatically detects which services changed and only
recreates those. Unchanged services keep running.

#### New environment variables in .env

If `.env.example` has new variables (e.g., `DEMO_DB_PASSWORD`), add them
to the existing `.env` — do NOT re-run `generate-env.sh` (it overwrites
all secrets).

```bash
# Generate a random password and append to .env
echo "DEMO_DB_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=' | head -c 16)" >> .env

# Then apply
docker compose up -d
```

#### setup.sh changes (system packages, SSH config, firewall)

Re-running `setup.sh` is safe — all steps are idempotent:

```bash
sudo ~/ai-lab-server-setup/setup.sh
```

This will skip already-installed components and only apply new changes.

#### Script changes (validate.sh, generate-env.sh, etc.)

Scripts run from the repo directory — `git pull` is enough, no restart needed.

### Step 4: Validate

```bash
lab-validate
```

Check that all services are running and APIs respond.

## Common Update Scenarios

### Adding a new service to docker-compose.yml

```bash
ssh lab@<server-ip>
cd ~/ai-lab-server-setup
git pull

# Add any new env vars to .env (check .env.example for new entries)
diff .env .env.example

# Add missing variables
echo "NEW_VAR=value" >> .env

# Start new service
docker compose up -d
```

### Bumping service versions

```bash
ssh lab@<server-ip>
cd ~/ai-lab-server-setup
git pull
docker compose pull          # download new images
docker compose up -d         # restart updated services
```

> **WARNING:** Before bumping Dify or n8n versions, check release notes
> for breaking changes or required database migrations.

### Updating Ollama models

Ollama runs natively — not managed by docker-compose:

```bash
ollama pull llama3.2         # updates to latest version
ollama pull nomic-embed-text
ollama list                  # verify
```

### Updating config files (fail2ban, nginx, aliases)

```bash
ssh lab@<server-ip>
cd ~/ai-lab-server-setup
git pull

# Fail2ban config
sudo cp config/fail2ban.conf /etc/fail2ban/jail.local
sudo systemctl restart fail2ban

# Shell aliases
cp config/bash_aliases ~/.bash_aliases
source ~/.bash_aliases

# Dify nginx
docker compose restart dify-nginx
```

## Safety Rules

- **Never re-run `generate-env.sh`** on a server with existing `.env` —
  it overwrites ALL secrets and breaks running services
- **Always `git pull` before `docker compose up -d`** — compose file and
  `.env` must be in sync
- **Check `.env.example` diff** after pull to catch new required variables
- **Backup volumes** before major version upgrades:

```bash
# List all project volumes
docker volume ls --filter name=ai-lab

# Backup a specific volume (example: n8n data)
docker run --rm -v n8n-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/n8n-data-backup.tar.gz -C /data .
```

## Rollback

If something breaks after an update:

```bash
# Revert to previous commit
cd ~/ai-lab-server-setup
git log --oneline -5         # find the previous working commit
git checkout <commit-hash> -- docker-compose.yml .env.example

# Restart with old config
docker compose up -d
```

For volume data rollback, restore from the backup created before the update.

# Troubleshooting

Common issues and solutions for AI Lab Server Setup.

## Collecting logs

### All services status

```bash
# Container status (running, restarting, exited)
docker compose ps

# System services
systemctl status docker ollama ssh ufw fail2ban
```

### Service logs

```bash
# All services
docker compose logs

# Specific service (last 50 lines, follow)
docker compose logs --tail=50 -f traefik
docker compose logs --tail=50 -f flowise
docker compose logs --tail=50 -f n8n
docker compose logs --tail=50 -f langfuse
docker compose logs --tail=50 -f dify-api
docker compose logs --tail=50 -f dify-worker
docker compose logs --tail=50 -f dify-web
docker compose logs --tail=50 -f dify-nginx

# All Dify services at once
docker compose logs --tail=30 dify-api dify-worker dify-web dify-nginx dify-db dify-redis

# Database logs
docker compose logs --tail=30 langfuse-db
docker compose logs --tail=30 dify-db
docker compose logs --tail=30 dify-redis
```

### System logs

```bash
# Docker daemon
sudo journalctl -u docker --since "1 hour ago" --no-pager

# Ollama (native)
sudo journalctl -u ollama --since "1 hour ago" --no-pager

# SSH
sudo journalctl -u ssh --since "1 hour ago" --no-pager

# Cloud-init (provisioning)
sudo cat /var/log/cloud-init-output.log
cloud-init status --long
```

### Network diagnostics

```bash
# Docker networks
docker network ls
docker network inspect traefik-public --format '{{range .Containers}}{{.Name}} {{end}}'

# Port bindings
sudo ss -tlnp | grep -E '80|443|11434|6333'

# Firewall rules
sudo ufw status verbose

# DNS resolution
dig +short flow.example.com
curl -sf -o /dev/null -w '%{http_code}' http://localhost:80
```

### Resource usage

```bash
# Container resource usage
docker stats --no-stream

# Disk usage
df -h
docker system df

# Memory
free -h
```

### Full diagnostic archive

Collect all logs, configs, and system info into a zip for support:

```bash
bash ~/ai-lab-server-setup/scripts/collect-diagnostics.sh
```

Output: `~/lab-diagnostics-YYYYMMDD-HHMM.tar.gz`

What it collects:

- System info (OS, CPU, memory, disk, network)
- Docker state (containers, images, networks, volumes, stats)
- Service logs (last 100 lines per container + systemd journals)
- Network diagnostics (ports, firewall, DNS)
- Sanitized configuration (secrets are redacted)
- Validation script output

Download the archive:

```bash
scp lab@<server-ip>:~/lab-diagnostics-*.tar.gz .
```

> **WARNING**: Review the archive before sharing — secrets are redacted
> automatically but verify manually.

## Traefik

### "client version 1.24 is too old" (Docker 29+)

**Symptom:** Traefik logs show repeated errors:

```
ERR Provider error: client version 1.24 is too old.
Minimum supported API version is 1.40
```

**Cause:** Docker Engine 29+ raised the minimum API version to 1.40, but Traefik
uses API v1.24. Known issue across all Traefik v3 versions.

**Fix:** Lower Docker Engine's minimum accepted API version:

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
echo -e '[Service]\nEnvironment="DOCKER_MIN_API_VERSION=1.24"' | \
  sudo tee /etc/systemd/system/docker.service.d/min_api_version.conf
sudo systemctl daemon-reload
sudo systemctl restart docker
docker compose up -d --force-recreate traefik
```

**Reference:** [Traefik Community Forum](https://community.traefik.io/t/traefik-stops-working-it-uses-old-api-version-1-24/29019)

### 404 on all subdomains

**Symptom:** All services return `404 page not found` via HTTPS.

**Cause:** Traefik can't discover Docker containers (see API version error above),
or the `DOMAIN` variable in `.env` doesn't match the actual domain.

**Fix:**

```bash
# Check domain
grep DOMAIN .env

# Check Traefik logs for errors
docker compose logs traefik
```

### 504 Gateway Timeout

**Symptom:** Traefik finds the route but returns 504.

**Cause:** Network name mismatch — Docker Compose prefixes network names with the
project directory (e.g. `ai-lab-server-setup_traefik-public`), but Traefik config
expects `traefik-public`.

**Fix:** The `docker-compose.yml` uses `name: traefik-public` to force the exact
network name. If you see 504 after a full restart:

```bash
# Verify network exists with correct name
docker network ls | grep traefik

# Full restart
docker compose down
docker compose up -d
```

### Let's Encrypt rate limit

**Symptom:** No TLS certificates issued, browser shows "Not Secure".

**Cause:** Let's Encrypt limits 5 certificates per domain per week.

**Fix:** Use staging CA for testing:

```yaml
# Add to Traefik command in docker-compose.yml:
- "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```

Staging certificates are untrusted by browsers but have no rate limits.

## n8n

### Mismatching encryption keys

**Symptom:** n8n crashes with:

```
Error: Mismatching encryption keys. The encryption key in the settings file
does not match the N8N_ENCRYPTION_KEY env var.
```

**Cause:** n8n generated its own encryption key on first start (stored in volume).
After regenerating `.env` with a new key, they no longer match.

**Fix:** Reset the n8n volume (loses all workflows and credentials):

```bash
docker compose down n8n
docker volume rm ai-lab-server-setup_n8n-data
docker compose up -d n8n
```

## Langfuse

### "CLICKHOUSE_URL is not configured"

**Symptom:** Langfuse container crashes with:

```
Error: CLICKHOUSE_URL is not configured
```

**Cause:** Langfuse V3 (`latest`) requires ClickHouse — too heavy for a lab VM.

**Fix:** Pin to Langfuse V2 in `.env`:

```bash
sed -i 's/LANGFUSE_VERSION=latest/LANGFUSE_VERSION=2/' .env
docker compose down langfuse
docker compose pull langfuse
docker compose up -d langfuse
```

### Database authentication failed

**Symptom:** Langfuse shows `P1000: Authentication failed against database server`.

**Cause:** The password in `.env` doesn't match what PostgreSQL was initialized with
(the old password is baked into the volume).

**Fix:** Reset the Langfuse database volume:

```bash
docker compose down langfuse langfuse-db
docker volume rm ai-lab-server-setup_langfuse-db-data
docker compose up -d langfuse-db langfuse
```

## Dify

### Missing environment variables

**Symptom:** Docker Compose warns about missing `DIFY_*` variables:

```
WARN: The "DIFY_SECRET_KEY" variable is not set. Defaulting to a blank string.
```

**Cause:** `.env` was created before Dify was added to the stack.

**Fix:** Regenerate `.env` or add variables manually:

```bash
# Option A: Regenerate (overwrites all secrets)
bash scripts/generate-env.sh denav.net user@example.com

# Option B: Add manually
cat >> .env << 'EOF'
DIFY_VERSION=latest
DIFY_SECRET_KEY=$(openssl rand -base64 32)
DIFY_DB_PASSWORD=$(openssl rand -base64 16)
DIFY_REDIS_PASSWORD=$(openssl rand -base64 16)
EOF
```

## Cloud-Init

### setup.sh: Permission denied

**Cause:** Git doesn't preserve file permissions on clone.

**Fix:** Always use `bash setup.sh` instead of `./setup.sh`.

### /home/lab: Permission denied

**Cause:** User home directory not owned by lab user after creation.

**Fix:** `setup.sh` runs `chown -R lab:lab /home/lab` after user creation.

### docker group doesn't exist

**Cause:** Docker isn't installed yet when cloud-init creates the user.

**Fix:** Don't add `docker` group in cloud-init `users:` section. The `setup.sh`
script adds the user to the docker group after Docker is installed.

### Ubuntu 24.04: ssh.service not sshd.service

**Cause:** Ubuntu 24.04 renamed the SSH service from `sshd` to `ssh`.

**Fix:** Use `systemctl restart ssh` (not `sshd`).

### YAML colon-space breaks runcmd

**Cause:** YAML interprets `key: value` as a mapping. Lines like `Run: lab` or
`WARN: repo` in runcmd break cloud-init.

**Fix:** Avoid colons followed by spaces in runcmd values, or quote the entire line.

## General

### Full clean redeploy

Reset everything (all data lost):

```bash
cd ~/ai-lab-server-setup
docker compose down -v
docker compose pull
docker compose up -d
```

### Check all services

```bash
docker compose ps
~/ai-lab-server-setup/scripts/validate.sh
```

### View generated credentials

```bash
cat .secrets
```

### DNS verification

```bash
# Check DNS resolution (from local machine)
nslookup flow.example.com 8.8.8.8

# Check from server
dig +short flow.example.com
```

### Hetzner DNS CNAME records

When creating CNAME records in Hetzner DNS Console, use the **subdomain only**
as the value (e.g. `ai`), not the full domain (`ai.example.com`). The full domain
gets interpreted as `ai.example.com.example.com`.

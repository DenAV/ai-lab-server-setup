# Upgrading Dify

How to upgrade Dify to a new major version on the AI Lab server.

## Version History

| Version | Architecture | Key Changes |
|---------|-------------|-------------|
| 0.15.x | API + Web + Worker | Basic platform, local storage |
| 1.x | API + Web + Worker + Sandbox + Plugin Daemon + Nginx + Beat | Plugin system, OpenDAL storage, code sandbox |

## Before You Start

- Check [Dify release notes](https://github.com/langgenius/dify/releases) for breaking changes
- Note: minor version bumps (e.g., 1.12 → 1.13) are usually safe
- Major architecture changes (e.g., 0.x → 1.x) require extra steps

## Upgrade Procedure

### Step 1: Backup

Always back up Dify data before a major upgrade:

```bash
cd ~/ai-lab-server-setup

# Backup PostgreSQL data
docker run --rm \
  -v ai-lab-server-setup_dify-db-data:/data \
  -v $(pwd):/backup alpine \
  tar czf /backup/dify-db-backup-$(date +%Y%m%d).tar.gz -C /data .

# Backup file storage (uploaded files, knowledge base)
docker run --rm \
  -v ai-lab-server-setup_dify-storage:/data \
  -v $(pwd):/backup alpine \
  tar czf /backup/dify-storage-backup-$(date +%Y%m%d).tar.gz -C /data .

echo "Backups saved:"
ls -lh ~/ai-lab-server-setup/dify-*-backup-*.tar.gz
```

### Step 2: Update .env

```bash
# Check current version
grep DIFY_VERSION .env

# Update to new version
sed -i 's/DIFY_VERSION=.*/DIFY_VERSION=1.13.3/' .env

# Verify
grep DIFY_VERSION .env
```

### Step 3: Add New Environment Variables

Major Dify versions may introduce new required variables. Check what is
missing:

```bash
# Show variables in .env.example that are not in .env
diff <(grep -oP '^\w+' .env.example | sort) <(grep -oP '^\w+' .env | sort) | grep '<'
```

#### 0.15.x → 1.13.x: New Variables

The 1.x architecture adds sandbox (code execution) and plugin system.
Generate and append the missing keys:

```bash
echo "" >> .env
echo "# Dify 1.x — Sandbox + Plugins" >> .env
echo "DIFY_SANDBOX_VERSION=0.2.14" >> .env
echo "DIFY_PLUGIN_VERSION=0.5.3-local" >> .env
echo "DIFY_SANDBOX_KEY=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)" >> .env
echo "DIFY_PLUGIN_DAEMON_KEY=$(openssl rand -base64 48 | tr -d '/+=' | head -c 48)" >> .env
echo "DIFY_PLUGIN_INNER_API_KEY=$(openssl rand -base64 48 | tr -d '/+=' | head -c 48)" >> .env
```

### Step 4: Pull and Restart

```bash
# Download new images
docker compose pull

# Recreate Dify containers (new services are created automatically)
docker compose up -d
```

Dify runs database migrations automatically on startup
(`MIGRATION_ENABLED=true` in docker-compose). The following new containers
are created for 1.x:

| Container | Purpose |
|-----------|---------|
| `dify-sandbox` | Secure code execution environment |
| `dify-plugin-daemon` | Plugin management and execution |
| `dify-beat` | Celery beat scheduler |
| `dify-nginx` | Internal routing (API + Web frontend) |

### Step 5: Validate

```bash
# Check all containers are running
lab-validate
# or directly:
~/ai-lab-server-setup/scripts/validate.sh
```

```bash
# Check Dify logs for migration errors
docker logs dify-api --tail 30 2>&1 | grep -iE "migration|error|ready"
```

### Step 6: Verify in Web UI

1. Open `https://dify.<domain>`
2. Log in (you may need to re-authenticate)
3. Check that existing apps and knowledge bases are intact
4. Verify model providers are still configured (Ollama, OpenAI)

## Architecture Differences

### Dify 0.15.x (3 containers)

```text
dify-api    :5001  ← API backend
dify-web    :3000  ← Frontend
dify-worker        ← Background tasks (Celery)
```

### Dify 1.13.x (8 containers)

```text
dify-nginx  :80    ← Reverse proxy (routes to API + Web)
dify-api    :5001  ← API backend
dify-web    :3000  ← Frontend
dify-worker        ← Background tasks (Celery)
dify-beat          ← Celery beat scheduler
dify-sandbox:8194  ← Code execution sandbox
dify-plugin-daemon :5002  ← Plugin runtime
dify-db     :5432  ← Dedicated PostgreSQL
dify-redis  :6379  ← Dedicated Redis
```

## Rollback

If the upgrade fails:

```bash
# Revert version in .env
sed -i 's/DIFY_VERSION=.*/DIFY_VERSION=0.15.3/' .env

# Restore database from backup
docker compose down
docker volume rm ai-lab-server-setup_dify-db-data
docker volume create ai-lab-server-setup_dify-db-data
docker run --rm \
  -v ai-lab-server-setup_dify-db-data:/data \
  -v $(pwd):/backup alpine \
  tar xzf /backup/dify-db-backup-YYYYMMDD.tar.gz -C /data

# Restart with old version
docker compose up -d
```

> Replace `YYYYMMDD` with the actual backup date.

## API Compatibility

The core chat API is backward-compatible across versions:

| Endpoint | 0.15.x | 1.13.x | Notes |
|----------|--------|--------|-------|
| `POST /v1/chat-messages` | Yes | Yes | Main chatbot API |
| `POST /v1/completion-messages` | Yes | Yes | Single completion |
| `GET /v1/messages` | Yes | Yes | Conversation history |
| `POST /v1/files/upload` | Yes | Yes | File upload |
| Knowledge Base API | Yes | Yes | Enhanced in 1.x |
| Plugin API | No | Yes | New in 1.x |

n8n workflows calling `/v1/chat-messages` work on both versions without
changes. Only the API key needs to be regenerated if creating a new app.

# Dify — AI Application Platform

## Overview

Dify is an open-source platform for building AI applications with visual
workflows, RAG pipelines, and agent orchestration. It provides a web UI
for creating and managing AI apps without writing code.

- **URL:** `https://dify.<domain>` (via Traefik)
- **Port (IP-only mode):** 80 (via dify-nginx container)
- **Components:** API server, background worker, web frontend, PostgreSQL, Redis
- **Default admin:** created on first visit (setup wizard)

## Architecture

```text
Traefik (443) → dify-nginx (80)
                 ├── /console/api, /api, /v1, /files → dify-api (5001)
                 └── /                               → dify-web (3000)

dify-api ←→ dify-db (PostgreSQL 16)
dify-api ←→ dify-redis (Redis 7)
dify-worker ←→ dify-db, dify-redis (async tasks)
```

## Configuration

### Environment Variables

In `.env`:

```bash
DIFY_VERSION=latest
DIFY_SECRET_KEY=CHANGE-ME-dify-secret-key
DIFY_DB_PASSWORD=CHANGE-ME-dify-db-password
DIFY_REDIS_PASSWORD=CHANGE-ME-dify-redis-password
```

Generate secure values:

```bash
# Generate DIFY_SECRET_KEY (32+ chars)
openssl rand -base64 32

# Generate passwords
openssl rand -base64 16
```

## First Launch

```bash
cd ~/ai-lab-server-setup
docker compose up -d

# Check all Dify containers are running
docker compose ps | grep dify
```

Open `https://dify.<domain>` (or `http://<server-ip>:80` without Traefik).
The setup wizard creates the admin account on first visit.

## Connect to Ollama

Dify can use Ollama as a model provider for local LLM inference.

1. Go to **Settings → Model Providers → Ollama**
2. Add a new model:
   - **Model Name:** `llama3.2`
   - **Base URL:** `http://ollama-compose:11434` (Docker Compose)
   - Or `http://host.docker.internal:11434` (native Ollama on host)
3. Click **Save**

> If Ollama is installed natively (via `setup.sh`), use `host.docker.internal`
> since Dify runs in Docker but Ollama runs on the host.

For native Ollama, ensure it listens on all interfaces:

```bash
sudo systemctl edit ollama
# Add: Environment="OLLAMA_HOST=0.0.0.0"
sudo systemctl restart ollama
```

## Connect to Qdrant

Dify supports Qdrant as a vector database for RAG (Knowledge Base).

1. Go to **Settings → Model Providers** and add an **Embedding Model** (e.g., `nomic-embed-text` via Ollama)
2. Create a **Knowledge Base** → choose **Qdrant** as vector store:
   - **URL:** `http://qdrant-compose:6333` (Docker Compose)
   - Or `http://host.docker.internal:6333` (native Qdrant on host)
   - **API Key:** value from `QDRANT_API_KEY` in `.env`

## Build a RAG Application

1. **Create Knowledge Base:**
   - Go to **Knowledge** → **Create Knowledge**
   - Upload documents (PDF, TXT, Markdown)
   - Dify chunks, embeds, and stores in Qdrant automatically

2. **Create App:**
   - Go to **Studio** → **Create App** → **Chat App**
   - In **Context**, link your Knowledge Base
   - Set the **Model** to `llama3.2` (Ollama)
   - Configure system prompt and retrieval settings

3. **Publish:**
   - Click **Publish** to get a shareable URL or API endpoint

## API Access

Dify provides an OpenAI-compatible API for each published app:

```bash
# Get API key from app settings → API Access
curl -X POST https://dify.<domain>/v1/chat-messages \
  -H "Authorization: Bearer app-YOUR-API-KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {},
    "query": "What is RAG?",
    "user": "test-user",
    "response_mode": "blocking"
  }'
```

### Python SDK

```bash
pip install dify-client
```

```python
from dify_client import ChatClient

client = ChatClient(api_key="app-YOUR-API-KEY")
client.base_url = "https://dify.<domain>/v1"

response = client.create_chat_message(
    inputs={},
    query="Explain vector databases",
    user="test-user",
    response_mode="blocking",
)
print(response.json()["answer"])
```

## Workflow Builder

Dify's visual workflow builder supports:

- **LLM nodes** — call any configured model
- **Knowledge Retrieval** — query RAG knowledge bases
- **Code nodes** — run Python/JavaScript inline
- **HTTP Request** — call external APIs
- **Conditional logic** — branching and loops
- **Variable aggregation** — collect and merge outputs

### Example: RAG Workflow

```text
Start → Knowledge Retrieval → LLM (with context) → Answer
```

1. Create a **Workflow App**
2. Add **Knowledge Retrieval** node → select your Knowledge Base
3. Add **LLM** node → connect retrieval output as context
4. Set system prompt: "Answer based on the provided context"

## Without Domain (IP Only)

Expose dify-nginx port directly:

```yaml
# In docker-compose.yml, add to dify-nginx:
ports:
  - "8080:80"
```

Access via `http://<server-ip>:8080`.

## Backup and Restore

### Backup

```bash
# Stop services
docker compose stop dify-api dify-worker dify-web dify-nginx

# Backup database
docker exec dify-db pg_dump -U dify dify > dify-backup-$(date +%Y%m%d).sql

# Backup storage (uploaded files)
docker cp dify-api:/app/api/storage ./dify-storage-backup/

docker compose start dify-api dify-worker dify-web dify-nginx
```

### Restore

```bash
docker compose stop dify-api dify-worker dify-web dify-nginx
cat dify-backup.sql | docker exec -i dify-db psql -U dify dify
docker cp ./dify-storage-backup/. dify-api:/app/api/storage/
docker compose start dify-api dify-worker dify-web dify-nginx
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Setup wizard not loading | Check all 5 containers: `docker compose ps \| grep dify` |
| "Connection refused" to Ollama | Use `host.docker.internal:11434` for native Ollama |
| Slow document processing | Check dify-worker logs: `docker compose logs dify-worker` |
| 502 error via Traefik | Verify dify-nginx is on `traefik-public` network |
| Database connection error | Check dify-db health: `docker compose ps dify-db` |
| Redis connection error | Verify `DIFY_REDIS_PASSWORD` matches in `.env` |
| File upload fails | Check storage volume permissions and `client_max_body_size` |

### Check Logs

```bash
# API server
docker compose logs -f dify-api

# Background worker (document processing)
docker compose logs -f dify-worker

# Nginx routing
docker compose logs -f dify-nginx

# All Dify services
docker compose logs -f dify-api dify-worker dify-web dify-nginx dify-db dify-redis
```

# n8n — Workflow Automation

## Overview

n8n is an open-source workflow automation tool. Use it to connect AI services,
APIs, databases, and trigger automated pipelines.

- **Subdomain:** `n8n.<domain>`
- **Container port:** 5678
- **Data:** Docker volume `n8n-data`
- **Docs:** [docs.n8n.io](https://docs.n8n.io/)

## Configuration

### Environment Variables

In `.env`:

```bash
N8N_VERSION=latest
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=<strong-password>
N8N_ENCRYPTION_KEY=<random-key>
```

Generate secrets:

```bash
openssl rand -hex 32  # for N8N_ENCRYPTION_KEY
openssl rand -base64 16  # for N8N_BASIC_AUTH_PASSWORD
```

> **Important:** `N8N_ENCRYPTION_KEY` encrypts credentials stored in n8n.
> If you change it, all saved credentials become unreadable.

## First Login

1. Open `https://n8n.<domain>` in browser
2. Create your account (first-time setup)
3. Start building workflows

## Connecting to Ollama

1. Add an **HTTP Request** node
2. Set Method: POST
3. URL: `http://ollama-compose:11434/v1/chat/completions`
4. Body (JSON):

```json
{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "{{ $json.input }}"}]
}
```

Or use the **Ollama Chat Model** node (n8n AI nodes):

1. Add **AI Agent** or **Basic LLM Chain** node
2. Add **Ollama Chat Model** sub-node
3. Base URL: `http://ollama-compose:11434`
4. Model: `llama3.2`

## Connecting to Qdrant

1. Add **Qdrant Vector Store** node
2. Set URL: `http://qdrant-compose:6333`
3. Set API Key if configured
4. Set Collection Name

## Using FFmpeg Worker

Use the optional `ffmpeg-worker` when n8n workflows need audio or video
conversion without customizing the n8n image.

Start n8n with the worker compose file:

```bash
docker compose -f docker-compose.yml -f docker-compose.workers.yml up -d --build n8n ffmpeg-worker
```

In n8n, add an **HTTP Request** node:

1. Method: POST
2. URL: `http://ffmpeg-worker:8080/convert`
3. Body (JSON):

```json
{
  "input": "incoming/source.wav",
  "output": "processed/source.mp3",
  "preset": "mp3-128k"
}
```

Files are shared through `/data/cca`. See
[FFmpeg Worker](setup-ffmpeg-worker.md) for supported presets and operations.

## Example Workflows

### Webhook → Ollama → Response

1. **Webhook** (trigger) → receives HTTP POST
2. **Ollama Chat Model** → processes the message
3. **Respond to Webhook** → returns AI response

### File → Embeddings → Qdrant

1. **Read Binary File** → load document
2. **Extract Document Text** → parse content
3. **Text Splitter** → chunk text
4. **Embeddings** (Ollama, `nomic-embed-text`) → generate vectors
5. **Qdrant Vector Store Insert** → store in Qdrant

### Scheduled RAG Pipeline

1. **Schedule Trigger** → runs daily
2. **HTTP Request** → fetch data from API
3. **Code** → transform data
4. **Qdrant Vector Store Insert** → update vectors

## API Usage

```bash
# Execute workflow via webhook
curl -X POST https://n8n.<domain>/webhook/<webhook-id> \
  -H "Content-Type: application/json" \
  -d '{"input": "What is Kubernetes?"}'
```

## Credentials Storage

n8n encrypts credentials at rest using `N8N_ENCRYPTION_KEY`.

1. Settings → Credentials → Add New
2. Select credential type (HTTP, API Key, OAuth, etc.)
3. Fill in details — they are encrypted automatically

## Backup and Restore

```bash
# Backup
docker compose stop n8n
docker run --rm -v ai-lab-server-setup_n8n-data:/data -v $(pwd):/backup \
  ubuntu tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz /data
docker compose start n8n

# Restore
docker compose stop n8n
docker run --rm -v ai-lab-server-setup_n8n-data:/data -v $(pwd):/backup \
  ubuntu bash -c "rm -rf /data/* && tar xzf /backup/n8n-backup-YYYYMMDD.tar.gz -C /"
docker compose start n8n
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't connect to Ollama | Use `http://ollama-compose:11434`, not `localhost` |
| Webhook not reachable | Check `WEBHOOK_URL` in `.env` matches your domain |
| Credentials lost after restart | `N8N_ENCRYPTION_KEY` must not change |
| 502 Bad Gateway | Check container: `docker compose ps n8n` |
| Timezone wrong in schedules | Set `GENERIC_TIMEZONE` in `.env` |

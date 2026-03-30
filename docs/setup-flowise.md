# Flowise — Visual AI Agent Builder

## Overview

Flowise provides a drag-and-drop UI for building LLM workflows, RAG pipelines,
and AI agents without code.

- **Subdomain:** `flow.<domain>`
- **Container port:** 3000
- **Data:** Docker volume `flowise-data`
- **Docs:** [docs.flowiseai.com](https://docs.flowiseai.com/)

## Configuration

### Environment Variables

In `.env`:

```bash
FLOWISE_VERSION=latest
FLOWISE_USERNAME=admin
FLOWISE_PASSWORD=<strong-password>
FLOWISE_SECRETKEY_OVERWRITE=<random-secret>
```

Generate secrets:

```bash
openssl rand -hex 32  # for FLOWISE_SECRETKEY_OVERWRITE
openssl rand -base64 16  # for FLOWISE_PASSWORD
```

## First Login

1. Open `https://flow.<domain>` in browser
2. Login with `FLOWISE_USERNAME` / `FLOWISE_PASSWORD` from `.env`
3. Start building flows

## Connecting to Ollama

1. In Flowise, add a **ChatOllama** node
2. Set Base URL: `http://ollama-compose:11434` (Docker network)
3. Select model: `llama3.2`

> Use `ollama-compose` (container name), not `localhost` — Flowise runs
> inside Docker and needs the container network name.

## Connecting to Qdrant

1. Add a **Qdrant** node
2. Set URL: `http://qdrant-compose:6333`
3. Set API Key if configured
4. Set Collection Name

## Building a RAG Pipeline

1. **Document Loader** → PDF, text, or web scraper
2. **Text Splitter** → Recursive Character Text Splitter (chunk size: 1000)
3. **Embeddings** → Ollama Embeddings (`nomic-embed-text`)
4. **Vector Store** → Qdrant (`http://qdrant-compose:6333`)
5. **Chat Model** → ChatOllama (`llama3.2`)
6. **Conversational Retrieval QA Chain** → connects all nodes

## API Usage

```bash
# List chatflows
curl -H "Authorization: Bearer <api-key>" \
  https://flow.<domain>/api/v1/chatflows

# Send message to chatflow
curl -X POST https://flow.<domain>/api/v1/prediction/<chatflow-id> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <api-key>" \
  -d '{"question": "What is Docker?"}'
```

### Create API Key

1. Settings → API Keys → Add New
2. Copy the key for external access

## Backup and Restore

```bash
# Backup
docker compose stop flowise
docker run --rm -v ai-lab-server-setup_flowise-data:/data -v $(pwd):/backup \
  ubuntu tar czf /backup/flowise-backup-$(date +%Y%m%d).tar.gz /data
docker compose start flowise

# Restore
docker compose stop flowise
docker run --rm -v ai-lab-server-setup_flowise-data:/data -v $(pwd):/backup \
  ubuntu bash -c "rm -rf /data/* && tar xzf /backup/flowise-backup-YYYYMMDD.tar.gz -C /"
docker compose start flowise
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't connect to Ollama | Use `http://ollama-compose:11434`, not `localhost` |
| Can't connect to Qdrant | Use `http://qdrant-compose:6333`, not `localhost` |
| 502 Bad Gateway | Check container: `docker compose ps flowise` |
| Login fails | Verify credentials in `.env`, restart: `docker compose restart flowise` |
| Slow responses | Normal for CPU-only Ollama — consider larger server |

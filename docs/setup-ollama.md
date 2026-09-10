# Ollama

## Overview

Ollama is an optional Docker Compose service for hosts with enough memory for local
inference. It is not installed natively by `setup.sh`.

- **Profile:** `local-model`
- **Image:** `ollama/ollama:0.34.0`
- **Internal URL:** `http://ollama-compose:11434`
- **Models:** `ollama-data` Docker volume
- **Host port:** not published

The default cloud-only stack does not create or start Ollama.

## Enable Local Models

Set the profile in `.env` so subsequent Compose commands use the same mode:

```bash
COMPOSE_PROFILES=local-model
```

Start the stack and pull only models that fit the host:

```bash
docker compose up -d
docker compose exec ollama ollama pull llama3.2
docker compose exec ollama ollama pull nomic-embed-text
docker compose exec ollama ollama list
```

Alternatively, enable the profile for one command:

```bash
docker compose --profile local-model up -d
```

Local inference competes with Dify, n8n, Flowise, and OpenClaw for memory. Do not enable
the profile merely because the container starts; verify that the selected model fits
without sustained swap use or out-of-memory kills.

## Connect Services

All consumers use the internal Docker hostname:

| Platform | Base URL |
|----------|----------|
| OpenClaw | `http://ollama-compose:11434` |
| n8n | `http://ollama-compose:11434` |
| Flowise | `http://ollama-compose:11434` |
| Dify | `http://ollama-compose:11434` |

OpenClaw must use Ollama's native API URL without `/v1`. An HTTP Request node that
deliberately uses Ollama's OpenAI-compatible endpoint may append `/v1`.

## Disable Local Models

Remove `local-model` from `COMPOSE_PROFILES`, then stop and remove only the container:

```bash
docker compose --profile local-model stop ollama
docker compose --profile local-model rm -f ollama
```

These commands preserve `ollama-data`. Delete the volume only when model loss is
intentional and no workflow depends on it:

```bash
docker volume rm ai-lab-server-setup_ollama-data
```

## Operations

```bash
docker compose --profile local-model ps ollama
docker compose --profile local-model logs -f ollama
docker compose --profile local-model exec ollama ollama ps
docker stats ollama-compose
```

The base configuration is CPU-only. Add and review a host-specific Compose override
before enabling GPU devices; do not expose port `11434` publicly.

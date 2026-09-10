# OpenClaw

## Overview

OpenClaw runs as an isolated Docker Compose service. Its Gateway is published only on
the host loopback interface and is not connected to Traefik. Its private network can
optionally reach `ollama-compose` when the `local-model` profile is enabled.

- **Image:** `ghcr.io/openclaw/openclaw:2026.9.3`
- **Gateway:** `127.0.0.1:18789`
- **State:** `openclaw-data` Docker volume
- **Authentication:** Gateway token from `.env`

## Access

Forward the Gateway port over SSH:

```bash
ssh -L 18789:127.0.0.1:18789 lab@server.example.com
```

Then open `http://127.0.0.1:18789/` and enter the Gateway token.

## OpenAI Configuration

Set `OPENAI_API_KEY` directly in the server `.env`; never commit or paste the key into
documentation or chat. Initialize OpenClaw after the key is present:

```bash
docker compose run -T --rm --no-deps --entrypoint node openclaw \
  dist/index.js onboard --non-interactive --accept-risk --skip-health \
  --mode local --auth-choice openai-api-key --secret-input-mode ref \
  --gateway-auth token --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --skip-channels --no-install-daemon
docker compose up -d openclaw
```

## Local Model Configuration

Enable Ollama and pull a model first:

```bash
# In .env: COMPOSE_PROFILES=local-model
docker compose up -d
docker compose exec ollama ollama pull llama3.2
```

Then configure OpenClaw against Ollama's native API:

```bash
docker compose run -T --rm --no-deps --entrypoint node openclaw \
  dist/index.js onboard --non-interactive --accept-risk --skip-health \
  --auth-choice ollama \
  --custom-base-url "http://ollama-compose:11434" \
  --custom-model-id "llama3.2"
docker compose up -d openclaw
```

Do not append `/v1` to the OpenClaw Ollama URL because OpenClaw uses Ollama's native
tool-calling API.

## Validation

```bash
curl -fsS http://127.0.0.1:18789/healthz
docker compose exec openclaw node dist/index.js security audit
docker compose exec openclaw node dist/index.js models status
```

Do not mount the Docker socket or directories belonging to other services. Back up the
`openclaw-data` volume because it contains configuration, conversations, and provider
credentials.

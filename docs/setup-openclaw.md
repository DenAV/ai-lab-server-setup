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

## ChatGPT Subscription

Use ChatGPT/Codex OAuth for the primary model. This uses subscription quota and does not
require an OpenAI Platform API key:

```bash
docker compose exec openclaw node dist/index.js models auth login \
  --provider openai --set-default
```

The command requires an interactive terminal. On a headless server, open the displayed
authorization URL locally and paste the final redirect URL back into the SSH session.
OAuth credentials are stored in the `openclaw-data` volume.

Verify the account and canonical subscription-backed model route:

```bash
docker compose exec openclaw node dist/index.js models auth list --provider openai
docker compose exec openclaw node dist/index.js models set openai/gpt-5.6-sol
```

## OpenCode Go Fallback

OpenCode Go uses its own API key and paid subscription. Store the key interactively in
OpenClaw rather than in `.env` or Compose:

```bash
docker compose exec openclaw node dist/index.js models auth paste-api-key \
  --provider opencode-go
docker compose exec openclaw node dist/index.js models list --provider opencode-go
```

Choose a model from the live account catalog, then add it as a fallback. For example:

```bash
docker compose exec openclaw node dist/index.js models fallbacks add \
  opencode-go/kimi-k3
docker compose exec openclaw node dist/index.js models fallbacks list
```

OpenCode Go provides model inference for supported coding-agent traffic. It is not a
general replacement for OpenAI Platform endpoints such as embeddings, speech, or image
generation unless the selected OpenCode model explicitly supports that capability.

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

# OpenClaw

## Overview

OpenClaw runs as an isolated Docker Compose service. Its Gateway is published only on
the host loopback interface and is not connected to Traefik. Its private network can
optionally reach `ollama-compose` when the `local-model` profile is enabled.

- **Image:** `ghcr.io/openclaw/openclaw:2026.9.3`
- **Gateway:** `127.0.0.1:18789`
- **State:** `openclaw-data` Docker volume
- **Authentication:** Gateway token from `.env`

## Access from WSL

Keep a dedicated tunnel open in a local WSL terminal. The SSH alias only needs to exist
inside WSL; the Windows browser can use the forwarded localhost port:

```bash
ssh -N -L 18789:127.0.0.1:18789 <ssh-alias>
```

In a separate SSH session, ask OpenClaw for the dashboard URL:

```bash
cd ~/ai-lab-server-setup
docker compose exec openclaw node dist/index.js dashboard --no-open
```

If token auto-auth is not delivered, construct the URL from the server `.env`:

```bash
TOKEN="$(grep '^OPENCLAW_GATEWAY_TOKEN=' .env | cut -d= -f2-)"
printf 'http://127.0.0.1:18789/#token=%s\n' "$TOKEN"
unset TOKEN
```

Open the resulting URL in the Windows browser. The Gateway token authenticates the
browser to OpenClaw; it is separate from model-provider OAuth and must not be shared.

## ChatGPT Subscription

Use ChatGPT/Codex OAuth for the primary model. This uses subscription quota and does not
require or configure an OpenAI Platform API key. Device-code login avoids localhost
callback routing between the container, remote server, WSL, and Windows:

```bash
docker compose exec openclaw node dist/index.js models auth login \
  --provider openai --set-default --device-code
```

If device-code login is unavailable, omit `--device-code`, open the displayed URL in the
Windows browser, and complete authorization. The browser may fail to load
`localhost:1455`; copy the complete callback URL from its address bar and paste it into
the waiting SSH prompt. Treat callback URLs as temporary secrets. OAuth credentials are
stored in the `openclaw-data` volume.

Enable the bundled Codex harness and explicitly pin the subscription-backed model to it.
The runtime pin makes the route fail closed instead of silently calling the OpenAI
Platform API:

```bash
docker compose exec openclaw node dist/index.js models auth list --provider openai
docker compose exec openclaw node dist/index.js models set openai/gpt-5.6-sol
docker compose exec openclaw node dist/index.js plugins enable codex
docker compose exec openclaw node dist/index.js config set \
  agents.defaults.models \
  '{"openai/gpt-5.6-sol":{"agentRuntime":{"id":"codex"}}}' \
  --strict-json --merge
docker compose exec openclaw node dist/index.js config validate
docker compose restart openclaw
```

Verify the bundled managed app-server after the restart:

```bash
docker compose exec openclaw node dist/index.js doctor \
  --lint --only codex/managed-app-server --json
```

The expected result contains `"ok":true` and no findings. An additional
`@openclaw/codex` installation is unnecessary when this check passes.

Start a fresh terminal session so it does not retain the previous runtime:

```bash
docker compose exec openclaw node dist/index.js tui
```

Then run:

```text
/new
/status
/codex status
```

`/status` must report `Runtime: OpenAI Codex` before relying on subscription routing.

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

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Browser says a matching token is required | Gateway token was not included | Generate the `#token=` dashboard URL described in [Access from WSL](#access-from-wsl) |
| Browser fails at `localhost:1455` after OpenAI login | OAuth callback listener is remote or inside the container | Paste the full callback URL into the waiting SSH prompt, or repeat login with `--device-code` |
| `401 Unauthorized` from `api.openai.com/v1/responses` | OpenClaw used its embedded API runtime instead of Codex subscription routing | Enable `codex`, apply the explicit `agentRuntime.id: codex` pin, restart, and start a new session |
| Config warns that Codex is disabled | Codex config exists but the bundled plugin is inactive | Run `plugins enable codex`, validate, and restart OpenClaw |

Do not mount the Docker socket or directories belonging to other services. Back up the
`openclaw-data` volume because it contains configuration, conversations, and provider
credentials.

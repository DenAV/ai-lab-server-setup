# Compose Profiles

Traefik is the mandatory baseline and has no profile. Every optional product is isolated
behind one stable profile, so `docker compose up -d` with no profiles starts only
Traefik. Presets are component selections in `config/components.yml`; Phase 2 will add
the interactive and non-interactive selector that writes `COMPOSE_PROFILES`.

## Presets

| Preset | Profiles | Resolved services |
|--------|----------|-------------------|
| `n8n-cloud` | `n8n,litellm` | Traefik, n8n, LiteLLM, LiteLLM database |
| `dify-cloud` | `dify,qdrant,litellm` | Traefik, all Dify services, Qdrant, LiteLLM, LiteLLM database |
| `openclaw` | `openclaw` | Traefik and OpenClaw |

Set the resolved profiles in `.env` for persistent operation:

```dotenv
COMPOSE_PROFILES=n8n,litellm
```

Or apply them to one command without editing `.env`:

```bash
COMPOSE_PROFILES=n8n,litellm docker compose config --services
COMPOSE_PROFILES=n8n,litellm docker compose up -d
```

Inspect `docker compose config --services` before every first start or selection change.
It must list only the expected preset closure. Changing profiles does not remove existing
containers automatically; reconciliation and saved selection state arrive in Phase 2.

## Product Profiles

| Component | Profile | Notes |
|-----------|---------|-------|
| Demo database | `demo-db` | Explicit lab-project dependency |
| Dify | `dify` | All nine internal Dify services share the profile |
| FFmpeg worker | `ffmpeg-worker` | Requires `docker-compose.workers.yml` and n8n |
| Langfuse | `langfuse` | Application and database |
| LiteLLM | `litellm` | Gateway and dedicated database |
| n8n | `n8n` | Workflow automation service |
| Ollama | `local-model` | Explicit opt-in retained from ADR-0002 |
| OpenClaw | `openclaw` | Loopback-only Gateway |
| Qdrant | `qdrant` | Required by the Dify preset |

For workers, include the overlay and both dependency profiles:

```bash
COMPOSE_PROFILES=n8n,ffmpeg-worker docker compose \
  -f docker-compose.yml -f docker-compose.workers.yml config --services
```

For the OpenClaw rootless sandbox client, continue using the reviewed overlay from
[OpenClaw Rootless Sandbox](openclaw-rootless-sandbox.md).

## Data Safety

Removing a profile from `COMPOSE_PROFILES` does not delete its named volumes, but it also
does not stop an already running container. Until Phase 2 implements reconciliation,
preview with `docker compose config --services`, stop only the deselected services, and
never use `docker compose down -v` for a selection change.

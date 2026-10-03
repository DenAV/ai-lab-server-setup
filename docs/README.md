# Platform Documentation

Detailed setup and configuration guides for each component in the AI Lab stack.

## Platforms

| Guide | Component | Port |
|-------|-----------|------|
| [Ollama](platforms/setup-ollama.md) | Optional local LLM inference | internal |
| [OpenClaw](platforms/setup-openclaw.md) | Personal AI assistant | 18789 (loopback) |
| [Qdrant](platforms/setup-qdrant.md) | Vector database | 6333 |
| [LiteLLM](platforms/setup-litellm.md) | Internal model gateway | 4000 (loopback) |
| [Traefik](platforms/setup-traefik.md) | Reverse proxy + TLS | 80, 443 |
| [Dify](platforms/setup-dify.md) | AI application platform | `dify.<domain>` |
| [n8n](platforms/setup-n8n.md) | Workflow automation | `n8n.<domain>` |
| [Langfuse](platforms/setup-langfuse.md) | LLM observability | `trace.<domain>` |
| [FFmpeg Worker](platforms/setup-ffmpeg-worker.md) | Internal media processing worker | internal |

## Integrations

| Guide | Description |
|-------|-------------|
| [Platform Integration](integrations/platform-integration.md) | Internal URLs and cross-platform workflows |
| [n8n MCP](integrations/setup-n8n-mcp.md) | OpenCode connection to the n8n MCP endpoint |

## Demo Projects

See [demos/](demos/) for deployment guides of client demo projects.

## Operations

| Guide | Description |
|-------|-------------|
| [Compose Profiles](operations/compose-profiles.md) | Product profiles, presets, and safe selection behavior |
| [Update Server](operations/update-server.md) | Apply repo changes to a running server |
| [Upgrade Dify](operations/upgrade-dify.md) | Major version upgrade (0.15.x → 1.13.x) |
| [OpenClaw Rootless Sandbox](operations/openclaw-rootless-sandbox.md) | Isolated Docker client overlay |

## Project And Reference

| Guide | Description |
|-------|-------------|
| [Roadmap](project/ROADMAP.md) | Modular stack constructor delivery phases |
| [TODO](project/TODO.md) | Actionable project work |
| [Component Catalog](reference/component-catalog.md) | Machine-readable stack inventory and schema |
| [LiteLLM Contracts](reference/litellm-contracts.md) | Supported clients, providers, endpoints, and acceptance gates |
| [Resource Baselines](reference/resource-baselines.md) | Measured component usage and VPS sizing evidence |

## Architecture Decisions

See [adr/](adr/) for all decisions about platform choices and configuration.

| ADR | Decision |
|-----|----------|
| [ADR-0001](adr/0001-traefik-reverse-proxy.md) | Use Traefik as reverse proxy |
| [ADR-0002](adr/0002-ollama-compose-profile.md) | Run Ollama as an optional Compose service |
| [ADR-0003](adr/0003-qdrant-standalone-container.md) | Run Qdrant as standalone container |
| [ADR-0004](adr/0004-langfuse-for-observability.md) | Use Langfuse for LLM observability |
| [ADR-0005](adr/0005-ubuntu-2404-base.md) | Ubuntu 24.04 as base OS |
| [ADR-0006](adr/0006-lab-user-no-root.md) | Dedicated lab user, no root SSH |
| [ADR-0007](adr/0007-retire-flowise.md) | Retire Flowise; locate its historical setup guide |
| [ADR-0008](adr/0008-modular-stack-constructor.md) | Build a modular stack constructor with presets and a checklist |

# Platform Documentation

Detailed setup and configuration guides for each component in the AI Lab stack.

## AI Services

| Guide | Component | Port |
|-------|-----------|------|
| [Ollama](setup-ollama.md) | Optional local LLM inference | internal |
| [OpenClaw](setup-openclaw.md) | Personal AI assistant | 18789 (loopback) |
| [Qdrant](setup-qdrant.md) | Vector database | 6333 |

## Platform Stack (optional, via docker-compose)

| Guide | Component | Subdomain |
|-------|-----------|-----------|
| [Traefik](setup-traefik.md) | Reverse proxy + TLS | — |
| [Dify](setup-dify.md) | AI application platform | `dify.<domain>` |
| [n8n](setup-n8n.md) | Workflow automation | `n8n.<domain>` |
| [n8n MCP](setup-n8n-mcp.md) | OpenCode MCP connection to n8n | `n8n.<domain>/mcp-server/http` |
| [Langfuse](setup-langfuse.md) | LLM observability | `trace.<domain>` |
| [FFmpeg Worker](setup-ffmpeg-worker.md) | Internal media processing worker | internal |

## Integration Guide

[Integration Guide](integration-guide.md) — How to connect all services
together: Ollama, Qdrant, Dify, n8n, and Langfuse. Includes
connection matrix, per-integration setup steps, cross-platform workflows,
and troubleshooting.

## Demo Projects

See [demos/](demos/) for deployment guides of client demo projects.

## Operations

| Guide | Description |
|-------|-------------|
| [Update Server](update-server.md) | Apply repo changes to a running server |
| [Upgrade Dify](upgrade-dify.md) | Major version upgrade (0.15.x → 1.13.x) |
| [TODO](TODO.md) | Actionable project work |
| [Roadmap](ROADMAP.md) | Modular stack constructor delivery phases |

## Demo Projects

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

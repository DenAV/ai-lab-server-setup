# Platform Documentation

Detailed setup and configuration guides for each component in the AI Lab stack.

## Base Components (installed by setup.sh)

| Guide | Component | Port |
|-------|-----------|------|
| [Ollama](setup-ollama.md) | Local LLM inference | 11434 |
| [Qdrant](setup-qdrant.md) | Vector database | 6333 |

## Platform Stack (optional, via docker-compose)

| Guide | Component | Subdomain |
|-------|-----------|-----------|
| [Traefik](setup-traefik.md) | Reverse proxy + TLS | — |
| [Dify](setup-dify.md) | AI application platform | `dify.<domain>` |
| [Flowise](setup-flowise.md) | Visual AI agent builder | `flow.<domain>` |
| [n8n](setup-n8n.md) | Workflow automation | `n8n.<domain>` |
| [Langfuse](setup-langfuse.md) | LLM observability | `trace.<domain>` |

## Integration Guide

[Integration Guide](integration-guide.md) — How to connect all services
together: Ollama, Qdrant, Dify, Flowise, n8n, and Langfuse. Includes
connection matrix, per-integration setup steps, cross-platform workflows,
and troubleshooting.

## Demo Projects

See [demos/](demos/) for deployment guides of client demo projects.

## Operations

| Guide | Description |
|-------|-------------|
| [Update Server](update-server.md) | Apply repo changes to a running server |
| [Upgrade Dify](upgrade-dify.md) | Major version upgrade (0.15.x → 1.13.x) |

## Demo Projects

See [adr/](adr/) for all decisions about platform choices and configuration.

| ADR | Decision |
|-----|----------|
| [ADR-0001](adr/0001-traefik-reverse-proxy.md) | Use Traefik as reverse proxy |
| [ADR-0002](adr/0002-ollama-native-install.md) | Install Ollama natively, not in Docker |
| [ADR-0003](adr/0003-qdrant-standalone-container.md) | Run Qdrant as standalone container |
| [ADR-0004](adr/0004-langfuse-for-observability.md) | Use Langfuse for LLM observability |
| [ADR-0005](adr/0005-ubuntu-2404-base.md) | Ubuntu 24.04 as base OS |
| [ADR-0006](adr/0006-lab-user-no-root.md) | Dedicated lab user, no root SSH |

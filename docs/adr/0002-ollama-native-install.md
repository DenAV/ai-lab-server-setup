# ADR-0002: Install Ollama Natively, Not in Docker

- **Status:** accepted
- **Date:** 2026-03-30

## Context

Ollama can run as a native systemd service or inside a Docker container.
For a lab environment that uses CPU-only inference, we need to decide
which approach provides the best experience.

## Decision

Install Ollama **natively** on the host via the official install script.
The Docker Compose stack includes an Ollama container (`ollama-compose`)
separately for services that need Docker-internal access.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Native install** | Direct CLI (`ollama run`), system-wide access, simpler model management, direct hardware access | Models stored on host, not containerized |
| Docker only | Fully containerized, consistent with other services | No CLI access from host, model management via API only, GPU passthrough more complex |
| Both (current) | CLI for interactive use, Docker for service-to-service | Two instances, potential port conflicts |

## Consequences

### Positive

- `ollama` CLI available system-wide for interactive use
- Models accessible from host Python scripts and venvs
- systemd manages lifecycle (auto-start on boot)
- Simpler model management (`ollama pull`, `ollama list`)

### Negative

- Models stored on host filesystem, not in Docker volumes
- Docker Compose Ollama container is a separate instance with its own models
- Need to manage two Ollama instances if both native and Docker are used

### Risks

- Port conflict if both native (11434) and Docker are running — mitigated by
  using different container name (`ollama-compose`) without port mapping

# ADR-0002: Run Ollama as an Optional Compose Service

- **Status:** superseded on 2026-09-10
- **Date:** 2026-03-30

## Context

The original deployment ran both a native systemd service and a Docker Compose
container. This duplicated models and made host behavior differ from the repository's
declared Compose state. Some lab servers also lack enough memory for local inference.

## Decision

Do not install Ollama natively. Keep `ollama-compose` behind the `local-model` Compose
profile, with models persisted in `ollama-data` and no published host port.

The default stack uses cloud model providers and does not start Ollama. Hosts with
sufficient resources enable the profile explicitly and select models appropriate for
their available memory or GPU configuration.

## Consequences

### Positive

- One Ollama runtime and one model store per host
- Reproducible service configuration and lifecycle through Docker Compose
- No unauthenticated Ollama API exposed on the host network
- Resource-constrained servers avoid downloading or loading local models
- Dify, n8n, Flowise, and OpenClaw share the same internal endpoint

### Negative

- Host commands use `docker compose exec ollama ollama ...`
- GPU acceleration requires a host-specific, reviewed Compose override
- Removing the profile without migrating consumers breaks saved local-model settings

### Risks

- Local models can exhaust RAM or trigger heavy swap use alongside the platform stack
- Deleting `ollama-data` permanently removes downloaded models

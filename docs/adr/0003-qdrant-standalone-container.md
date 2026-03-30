# ADR-0003: Run Qdrant as Standalone Container

- **Status:** accepted
- **Date:** 2026-03-30

## Context

Qdrant is the vector database for RAG pipelines. It can run as:
- A standalone Docker container (started by `setup.sh`)
- Part of the Docker Compose stack
- A native binary

We need it available immediately after `setup.sh`, before the optional
Docker Compose stack is deployed.

## Decision

Run Qdrant as a **standalone Docker container** started by `setup.sh`.
The Docker Compose stack includes a separate Qdrant instance
(`qdrant-compose`) for services that need Docker-internal access.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Standalone container** | Available immediately, simple management, accessible from host | Not managed by docker-compose lifecycle |
| Docker Compose only | Unified management, consistent with other services | Only available after `docker compose up` |
| Native binary | No Docker dependency | Manual updates, no restart policy, complex setup |
| Managed service (Qdrant Cloud) | No maintenance | Costs money, network latency, needs internet |

## Consequences

### Positive

- Available immediately after `setup.sh` (no docker-compose needed)
- Accessible from host at `localhost:6333`
- Persistent data via Docker volume (`qdrant_data`)
- Auto-restart via `--restart unless-stopped`
- Pinned version (`v1.12.1`) for reproducibility

### Negative

- Not managed by `docker compose down/up` lifecycle
- Two Qdrant instances if Docker Compose stack is also deployed
- Must remember to stop manually: `docker stop qdrant`

### Risks

- Port 6333 conflict if both standalone and compose Qdrant run —
  mitigated by different container names (`qdrant` vs `qdrant-compose`)

# ADR-0004: Use Langfuse for LLM Observability

- **Status:** accepted
- **Date:** 2026-03-30

## Context

LLM applications need observability: tracing, cost tracking, latency metrics,
and quality evaluation. We need a self-hosted solution that integrates with
Ollama, Flowise, n8n, and Python scripts.

## Decision

Use **Langfuse** (self-hosted) for LLM observability.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Langfuse** | Self-hosted, OpenAI SDK integration, LangChain support, prompt management, cost tracking | Needs PostgreSQL, heavier than alternatives |
| LangSmith | Official LangChain tool, polished UI | Cloud-only (no self-host), costs money |
| Phoenix (Arize) | Open source, good tracing UI | Less mature, fewer integrations |
| Custom logging | Full control, lightweight | Build everything from scratch |
| None | No overhead | Blind to LLM behavior, costs, quality |

## Consequences

### Positive

- Full trace visibility (input/output/latency/cost per LLM call)
- Drop-in integration with OpenAI Python SDK (works with Ollama)
- Prompt versioning and management
- Dataset creation for evaluation
- Self-hosted — data stays on the server

### Negative

- Requires PostgreSQL container (resource overhead)
- UI can be slow on small servers with large trace volumes
- Learning curve for trace/span/generation concepts

### Risks

- PostgreSQL data growth on disk — add monitoring for disk usage
- Database password must be secured (set in `.env`, never committed)

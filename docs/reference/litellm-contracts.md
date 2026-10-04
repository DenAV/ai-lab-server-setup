# LiteLLM Integration Contracts

This document declares the initial, deliberately narrow LiteLLM contract for ADR-0008.
It is a Phase 0 compatibility decision, not a deployed or acceptance-tested service. The
machine-readable source is `config/litellm-contracts.yml`, reviewed against LiteLLM
`v1.103.2` and the repository's pinned client versions on 2026-10-02. Every capability
remains declared or conditional until Phase 1 executes its named acceptance tests.

## Gateway Contract

The initial gateway declares these client surfaces:

| Endpoint | Auth | Contract |
|----------|------|----------|
| `GET /health/liveliness` | none | Process probe; no dependency or provider call |
| `GET /health/readiness` | none | Readiness probe; returns `503` when its configured database is unavailable |
| `GET /v1/models` | virtual key | Only aliases allowed for that client key |
| `POST /v1/chat/completions` | virtual key | Text chat through the `lab-chat` alias |
| `POST /v1/embeddings` | virtual key | Text embeddings through the `lab-embedding` alias |

`GET /health` is operator-only and conditional because it makes real provider requests
and can consume tokens. Responses, rerank, image, speech, and transcription endpoints
remain deferred even when LiteLLM implements them; gateway support alone does not prove
client, payload, model, or provider compatibility.

## Client Matrix

| Client | Declared | Conditional | Deferred or excluded |
|--------|-----------|-------------|----------------------|
| n8n `2.40.7` | Chat Completions, embeddings | Streaming, tool calling | Responses API |
| Dify `1.13.3` | LLM/chat, text embeddings | Streaming, tool calling | Rerank, image, STT, TTS |
| OpenClaw `2026.9.3` | Native subscription/provider routes remain unchanged | none | LiteLLM custom provider |

n8n's OpenAI credential supports a custom Base URL and model discovery through
`/models`. The current OpenAI Chat Model defaults to the Responses API, so every LiteLLM
configuration must disable **Use Responses API** until that path has its own acceptance
tests. The Embeddings OpenAI node explicitly supports a self-hosted Base URL.

Dify uses OpenAI API Compatible plugin `0.0.68`, reviewed at commit `f6b4a6a`. Configure
the LLM base as `http://litellm:4000/v1`. For text embeddings, configure
`http://litellm:4000` because the plugin appends the API version for non-LLM model types;
the acceptance test must reject a duplicated `/v1/v1` path.

OpenClaw can configure custom OpenAI-compatible providers, but custom routes require
explicit capability metadata. Its current ChatGPT/Codex subscription runtime is not an
API-key provider credential and must not be routed through LiteLLM.

## Provider Matrix

| Provider | Chat eligibility | Embedding eligibility | Conditions |
|----------|------------------|-----------------------|------------|
| OpenAI API | eligible | eligible | API key billing; test each alias |
| Anthropic API | eligible | excluded | Test normalized parameters and tools per model |
| Google Gemini API | eligible | eligible | Configure distinct chat and embedding models |
| Ollama | eligible | conditional | Requires `local-model`; capabilities vary by model |
| Arbitrary OpenAI-compatible endpoint | excluded | excluded | Add a provider-specific contract first |

Eligibility means LiteLLM documents the provider path. It does not approve every model,
parameter, streaming mode, tool schema, or embedding dimension. Every model alias must
pass the acceptance tests in `config/litellm-contracts.yml` before selection.

## Credential Boundary

- Add upstream provider credentials only through the SSH-tunneled loopback LiteLLM Admin UI;
  retain them encrypted in its dedicated database with `LITELLM_SALT_KEY`.
- Authenticate the `chatgpt/` subscription provider interactively before model creation
  and persist its OAuth tokens in the sensitive `litellm-chatgpt-auth` volume.
- Keep the master key in the administrative boundary; never place it in n8n or Dify.
- Issue separate model-limited virtual keys for n8n and Dify.
- Permit only declared clients on `litellm-clients`; isolate PostgreSQL on
  `litellm-backend` and optional model/telemetry services on `litellm-upstreams`.
- Disable LiteLLM Traefik discovery and bind its host port only to `127.0.0.1`.
- Treat SSH access as the remote network boundary and LiteLLM login as the user identity boundary.
- Keep administrative access on host loopback through an SSH tunnel.
- After verifying a password-backed `proxy_admin`, disable shared environment-credential
  UI login while retaining the master key for API administration and recovery.
- Set `litellm_settings.turn_off_message_logging: true` before client traffic. Verify
  with sentinel content that prompts and responses are absent from logs and traces.
- Never log credentials or key values.

## Langfuse

The evaluated LiteLLM `v1.103.2` image pins `langfuse>=2.59.7,<3.0` and contains its v2
callback implementation, so this repository's Langfuse v2 is not excluded by the newer
live LiteLLM documentation. The callback remains conditional until a redacted trace
smoke test passes. Prompt and response logging stays disabled by default. Upgrading to a
later LiteLLM callback must re-evaluate the current Langfuse server requirement first.

## Acceptance Gate

Before a client/provider combination becomes selectable:

1. Verify liveness and readiness without provider calls.
2. Verify unauthenticated model access is denied.
3. Verify each client key lists and invokes only approved aliases.
4. Run deterministic chat and embedding requests.
5. Confirm embedding dimensions remain stable through indexing and retrieval.
6. Test streaming cancellation and complete output reconstruction.
7. Complete a tool request, tool result, and final-response round trip.
8. Confirm n8n and Dify contain no upstream provider credentials.
9. Confirm OpenClaw's existing subscription route remains unchanged.

## Sources

- [LiteLLM Supported Endpoints](https://docs.litellm.ai/docs/supported_endpoints)
- [LiteLLM Health Checks](https://docs.litellm.ai/docs/proxy/health)
- [LiteLLM Virtual Keys](https://docs.litellm.ai/docs/proxy/virtual_keys)
- [LiteLLM v1.103.2 dependency manifest](https://github.com/BerriAI/litellm/blob/v1.103.2/pyproject.toml)
- [LiteLLM v1.103.2 Langfuse callback](https://github.com/BerriAI/litellm/blob/v1.103.2/litellm/integrations/langfuse/langfuse.py)
- [LiteLLM v1.103.2 release](https://github.com/BerriAI/litellm/releases/tag/v1.103.2)
- [n8n 2.40.7 OpenAI credential](https://github.com/n8n-io/n8n/blob/n8n%402.40.7/packages/nodes-base/credentials/OpenAiApi.credentials.ts)
- [n8n 2.40.7 OpenAI Chat Model](https://github.com/n8n-io/n8n/blob/n8n%402.40.7/packages/%40n8n/nodes-langchain/nodes/llms/LMChatOpenAi/LmChatOpenAi.node.ts)
- [n8n Embeddings OpenAI](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.embeddingsopenai/)
- [Dify OpenAI API Compatible plugin 0.0.68](https://github.com/langgenius/dify-official-plugins/tree/f6b4a6a945b4e5909d7c9ceb4c593505f1a3238d/models/openai_api_compatible)
- [OpenClaw custom providers](https://docs.openclaw.ai/concepts/model-providers/custom-providers)
- [Langfuse v2 to v3 migration](https://langfuse.com/self-hosting/upgrade-guides/upgrade-v2-to-v3)

All sources were accessed on 2026-10-02. Revalidate them when changing the LiteLLM or
client version pins.

# Integration Guide — Using Services Together

Most application services share `ai-net`, while sensitive service boundaries use
additional private networks. In particular, LiteLLM clients use `litellm-clients`, its
database uses `litellm-backend`, and optional model or telemetry services use
`litellm-upstreams`.

## Service Connection Map

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {
  'lineColor': '#64748b',
  'textColor': '#1e293b',
  'clusterBkg': '#f1f5f9',
  'clusterBorder': '#94a3b8'
}}}%%
graph TD
    Internet((Internet)) -->|HTTPS :443| Traefik["Traefik\nReverse Proxy + TLS"]

    Traefik --> Dify["Dify\ndify.domain"]
    Traefik --> n8n["n8n\nn8n.domain"]
    Traefik --> Langfuse["Langfuse\ntrace.domain"]

    subgraph ai-net["ai-net Docker network"]
        Ollama["Ollama :11434"]
        Qdrant["Qdrant :6333"]
    end

    subgraph litellm-clients["litellm-clients private network"]
        LiteLLM["LiteLLM :4000"]
    end

    Dify -->|LLM + embeddings| Ollama
    Dify -->|vector store| Qdrant
    Dify -.->|traces| Langfuse

    n8n -->|LLM + embeddings| Ollama
    n8n -->|vector store| Qdrant
    n8n -.->|traces| Langfuse
    n8n -->|virtual key| LiteLLM
    Dify -->|virtual key| LiteLLM


    style Internet fill:#6b7280,stroke:#4b5563,color:#fff
    style Traefik fill:#24a1c1,stroke:#1b7a93,color:#fff
    style Dify fill:#1677ff,stroke:#0958d9,color:#fff
    style n8n fill:#ff6d5a,stroke:#e5553d,color:#fff
    style Langfuse fill:#f5a623,stroke:#d48b0f,color:#000
    style Ollama fill:#1a1a2e,stroke:#0f0f1a,color:#fff
    style Qdrant fill:#dc244c,stroke:#b01d3d,color:#fff
```

## Internal Connection Reference

Services on a shared Docker network use container names as hostnames.

| Service | Internal URL | Protocol | Auth |
|---------|-------------|----------|------|
| Ollama | `http://ollama-compose:11434` | HTTP / native and OpenAI-compatible | None |
| Qdrant | `http://qdrant-compose:6333` | HTTP REST | `QDRANT_API_KEY` from `.env` |
| Demo DB | `postgresql://demo:<password>@demo-db:5432/demo` | PostgreSQL | `DEMO_DB_PASSWORD` from `.env` |
| Langfuse | `https://trace.<domain>` | HTTPS | API key (Public + Secret) |
| n8n | `https://n8n.<domain>` | HTTPS | Account credentials |
| Dify | `https://dify.<domain>` | HTTPS | Account credentials |
| LiteLLM | `http://litellm:4000/v1` | HTTP / OpenAI-compatible | Model-limited virtual key |

> **Note:** Ollama is optional. Set `COMPOSE_PROFILES=local-model` before using
> the internal endpoint.

## Integration Matrix

Which service can connect to which, and what for:

| From → To | Ollama | Qdrant | Langfuse | n8n | Dify |
|-----------|--------|--------|----------|-----|------|
| **n8n** | LLM chat, embeddings | Vector store (RAG) | Tracing (via HTTP) | — | Trigger workflows |
| **Dify** | LLM chat, embeddings | Knowledge base storage | Tracing (native) | Call webhooks | — |
| **Langfuse** | — | — | — | — | — |

## Ollama — LLM for All Services

Ollama provides local LLM inference and embeddings to every AI platform.

### Required Models

Pull these models before using integrations:

```bash
# Chat / reasoning model
docker compose exec ollama ollama pull llama3.2

# Embedding model (required for RAG)
docker compose exec ollama ollama pull nomic-embed-text
```

### Connect from n8n

**Option A — AI Agent nodes (recommended):**

1. Add **AI Agent** or **Basic LLM Chain** root node
2. Attach **Ollama Chat Model** sub-node
3. Set Base URL: `http://ollama-compose:11434`
4. Select Model: `llama3.2`

**Option B — HTTP Request node:**

1. Add **HTTP Request** node → POST
2. URL: `http://ollama-compose:11434/v1/chat/completions`
3. Body (JSON):

```json
{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "Hello"}]
}
```

### Connect from Dify

1. Go to **Settings → Model Providers → Ollama**
2. Add model:
   - Model Name: `llama3.2`
   - Base URL: `http://ollama-compose:11434`
3. For embeddings, add `nomic-embed-text` the same way

> Enable the `local-model` profile as described in
> [Ollama Setup](../platforms/setup-ollama.md).

## Qdrant — Vector Database for RAG

Qdrant stores embeddings and enables semantic search across all platforms.

### Connect from n8n

1. Go to **Settings → Credentials → Add Credential → Qdrant**
2. API URL: `http://qdrant-compose:6333`
3. API Key: value of `QDRANT_API_KEY` from `.env`

Use the **Qdrant Vector Store** node in AI workflows:

- **Insert mode:** store document embeddings
- **Retrieve mode:** search for similar documents (RAG)

Always attach an **Embeddings** sub-node (Ollama Embeddings, model
`nomic-embed-text`) to the Qdrant Vector Store node.

### Connect from Dify

1. Create a **Knowledge Base**
2. Choose **Qdrant** as vector store:
   - URL: `http://qdrant-compose:6333`
   - API Key: from `.env`
3. Select embedding model (e.g., `nomic-embed-text` via Ollama)
4. Upload and index documents

### Important

- Use the **same embedding model** for indexing and retrieval
- `nomic-embed-text` produces 768-dimension vectors
- Collections are created automatically on first insert

## Langfuse — Observability for All AI Services

Langfuse traces LLM calls, measures latency, and tracks token usage.

### Setup (one-time)

1. Open `https://trace.<domain>`, create an account
2. Create a project
3. Go to **Settings → API Keys → Create API Key**
4. Save the **Public Key** (`pk-...`) and **Secret Key** (`sk-...`)

### Connect from n8n

Use the **HTTP Request** node to send traces to the Langfuse API:

1. POST to `https://trace.<domain>/api/public/ingestion`
2. Headers: `Authorization: Basic <base64(publicKey:secretKey)>`
3. Body: Langfuse ingestion format

Or use a **Code** node with the Langfuse SDK for richer tracing.

### Connect from Dify

Dify has native Langfuse integration:

1. Go to **Settings → Monitoring → LLM Ops**
2. Select **Langfuse**
3. Enter:
   - Host: `https://trace.<domain>`
   - Public Key: `pk-...`
   - Secret Key: `sk-...`

All LLM calls in Dify are now automatically traced.

### Connect from Python

```python
from langfuse.openai import openai

client = openai.OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="unused",
)

# All calls are automatically traced
response = client.chat.completions.create(
    model="llama3.2",
    messages=[{"role": "user", "content": "Hello"}],
)
```

Set environment variables:

```bash
export LANGFUSE_PUBLIC_KEY=pk-...
export LANGFUSE_SECRET_KEY=sk-...
export LANGFUSE_HOST=https://trace.<domain>
```

## Cross-Platform Workflows

### n8n triggers Dify

Call a Dify chatbot from an n8n workflow:

1. In Dify: create an app, go to **API Access**, copy the API key
2. In n8n: add **HTTP Request** node → POST
   - URL: `https://dify.<domain>/v1/chat-messages`
   - Headers: `Authorization: Bearer <dify-api-key>`
   - Body:

```json
{
  "inputs": {},
  "query": "{{ $json.question }}",
  "user": "n8n-workflow"
}
```

### Complete RAG Pipeline (n8n + Qdrant + Ollama)

```text
Schedule Trigger → HTTP Request (fetch docs) → Text Splitter
  → Ollama Embeddings (nomic-embed-text) → Qdrant Vector Store (Insert)
```

Then for querying:

```text
Chat Trigger → AI Agent → Vector Store Retriever (Qdrant)
  → Ollama Chat Model (llama3.2) → Response
```

### Complete RAG Pipeline (Dify)

1. Create Knowledge Base → upload documents → auto-indexed in Qdrant
2. Create a Chatbot app → attach Knowledge Base as context
3. Traces appear automatically in Langfuse

## Troubleshooting Connections

| Problem | Cause | Fix |
|---------|-------|-----|
| `ECONNREFUSED` to Ollama | Profile disabled or wrong host | Enable `local-model` and use `ollama-compose:11434` |
| `ECONNREFUSED` to Qdrant | Wrong host | Use `qdrant-compose:6333` |
| `401 Unauthorized` on Qdrant | Missing API key | Add `QDRANT_API_KEY` from `.env` to credential settings |
| Embedding dimension mismatch | Mixed models | Use the same embedding model for insert and search |
| Langfuse traces not appearing | Wrong keys | Verify Public Key and Secret Key, check Langfuse project |
| n8n cannot reach Dify | Network issue | Both must be on `ai-net` and `traefik-public` networks |

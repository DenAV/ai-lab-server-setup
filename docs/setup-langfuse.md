# Langfuse — LLM Observability

## Overview

Langfuse provides tracing, metrics, and cost tracking for LLM applications.
Self-hosted with a PostgreSQL backend.

- **Subdomain:** `trace.<domain>`
- **Container port:** 3000
- **Database:** PostgreSQL 16 (separate container `langfuse-db`)
- **Data:** Docker volume `langfuse-db-data`
- **Docs:** [langfuse.com/docs](https://langfuse.com/docs)

## Configuration

### Environment Variables

In `.env`:

```bash
LANGFUSE_VERSION=latest
LANGFUSE_SECRET_KEY=<random-secret>
LANGFUSE_NEXT_AUTH_SECRET=<random-secret>
LANGFUSE_SALT=<random-secret>
LANGFUSE_DB_PASSWORD=<strong-password>
```

Generate all secrets at once:

```bash
for var in LANGFUSE_SECRET_KEY LANGFUSE_NEXT_AUTH_SECRET LANGFUSE_SALT LANGFUSE_DB_PASSWORD; do
  echo "${var}=$(openssl rand -hex 32)"
done
```

## First Login

1. Open `https://trace.<domain>` in browser
2. Click **Sign Up** to create your account
3. Create a new project
4. Go to Settings → API Keys → Create API Key
5. Save the **Public Key** and **Secret Key**

## Integration with Python

```bash
pip install langfuse
```

### Direct Tracing

```python
from langfuse import Langfuse

langfuse = Langfuse(
    public_key="pk-...",
    secret_key="sk-...",
    host="https://trace.<domain>",
)

# Create a trace
trace = langfuse.trace(name="my-rag-pipeline")

# Log a generation
trace.generation(
    name="llm-call",
    model="llama3.2",
    input="What is Docker?",
    output="Docker is a platform for...",
    usage={"input": 10, "output": 50},
)

langfuse.flush()
```

### OpenAI SDK Integration (with Ollama)

```python
from langfuse.openai import openai

# Automatically traces all OpenAI SDK calls
client = openai.OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="unused",
)

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

### LangChain Integration

```python
from langfuse.callback import CallbackHandler

handler = CallbackHandler(
    public_key="pk-...",
    secret_key="sk-...",
    host="https://trace.<domain>",
)

# Pass to any LangChain call
chain.invoke({"input": "query"}, config={"callbacks": [handler]})
```

## Dashboard Features

| Feature | Description |
|---------|-------------|
| **Traces** | Full request lifecycle (spans, events, scores) |
| **Generations** | Individual LLM calls with input/output |
| **Scores** | Quality metrics (manual or automated) |
| **Cost Tracking** | Token usage and estimated costs per model |
| **Datasets** | Test datasets for evaluation |
| **Prompts** | Version-controlled prompt management |

## Connecting to Flowise

1. In Langfuse, create an API key
2. In Flowise, add **Langfuse** node to your chatflow
3. Set:
   - Base URL: `http://langfuse:3000` (Docker network)
   - Public Key: `pk-...`
   - Secret Key: `sk-...`

## Connecting to n8n

1. In n8n, add **HTTP Request** node after AI nodes
2. POST to `http://langfuse:3000/api/public/ingestion`
3. Pass trace data as JSON body

Or use the Langfuse n8n community node if available.

## Backup

```bash
# Backup PostgreSQL data
docker compose exec langfuse-db pg_dump -U langfuse langfuse > langfuse-backup-$(date +%Y%m%d).sql

# Restore
docker compose exec -i langfuse-db psql -U langfuse langfuse < langfuse-backup-YYYYMMDD.sql
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't sign up | Check container health: `docker compose ps langfuse` |
| Database connection error | Wait for healthcheck: `docker compose logs langfuse-db` |
| Traces not appearing | Verify API keys and `langfuse.flush()` after logging |
| 502 Bad Gateway | Check both `langfuse` and `langfuse-db` containers |
| Slow dashboard | PostgreSQL needs more memory on large datasets |

# Deploying reborn-ai-demo on AI Lab Server

Step-by-step guide for deploying the [reborn-ai-demo](https://github.com/DenAV/reborn-ai-demo)
project on a server provisioned with `ai-lab-server-setup`.

## Prerequisites

- Server provisioned with `setup.sh` (base setup complete)
- Platform stack running (`docker compose up -d`)
- Domain configured with DNS records (see [Traefik setup](../setup-traefik.md))
- All services accessible via HTTPS

## Gap Analysis

The ai-lab platform stack provides the infrastructure, but several adjustments
are needed for reborn-ai-demo:

### What the Lab Already Provides

| Requirement | Lab Service | Status |
|-------------|-------------|--------|
| n8n workflow engine | `n8n` via Traefik | Ready |
| Dify AI platform | `dify` (v1.13.3) via Traefik | Version mismatch — see below |
| Ollama LLM runtime | `ollama-compose` + native | Ready |
| Qdrant vector DB | `qdrant-compose` + standalone | Ready (reborn can use for Demo 5) |
| Langfuse tracing | `langfuse` via Traefik | Ready (reborn can use for observability) |
| Reverse proxy + TLS | Traefik with Let's Encrypt | Ready |
| PostgreSQL | `dify-db`, `langfuse-db`, `demo-db` | Partial — see below |
| Redis | `dify-redis` | Partial — see below |

### What Needs Configuration

| Gap | Severity | Description |
|-----|----------|-------------|
| Dify version | **Critical** | Lab runs Dify v1.13.3, reborn targets v0.15.3. API and config format differ significantly |
| OpenAI API key | **High** | Demos 1, 2, 4, 6, 7 require OpenAI API access (gpt-4o-mini) |
| n8n webhook URL | **High** | Must be `https://n8n.<domain>/` for Telegram/WhatsApp webhooks |
| Telegram Bot token | **High** | Demo 1 requires a registered Telegram bot |
| Chat logging DB | **Medium** | Demo 1 needs `chat_logs` table in `demo-db` PostgreSQL |
| WhatsApp Business API | **Low** | Demo 1 WhatsApp integration (paid API, optional) |

## Step-by-Step Configuration

### Step 1: Dify Version Compatibility

reborn-ai-demo was built for Dify v0.15.3. The lab runs Dify v1.13.3.

**Key differences:**

| Feature | Dify 0.15.x | Dify 1.13.x |
|---------|-------------|-------------|
| Architecture | API + Web + Worker | API + Web + Worker + Sandbox + Plugin Daemon + Nginx |
| Storage | Local filesystem | OpenDAL (filesystem, S3, etc.) |
| Plugins | Not supported | Full plugin system |
| API endpoints | `/v1/chat-messages` | `/v1/chat-messages` (compatible) |
| Knowledge Base | Built-in | Built-in (enhanced) |

**Action required:**

The core Dify chat API (`/v1/chat-messages`) is backward-compatible. The n8n
workflows in reborn-ai-demo should work with Dify 1.13.3 with minor adjustments:

1. Create the Dify app via web UI at `https://dify.<domain>`
2. Import the knowledge base documents manually (5 markdown files)
3. Configure the model provider (OpenAI or Ollama)
4. Get the API key from the app's API Access page
5. Update n8n workflow credentials with the new API key

The `dify-app-config.yml` is a reference — create the app manually via the UI.

### Step 2: Add External API Keys to .env

Add these variables to the existing `.env` file on the server:

```bash
# === External API Keys (for demo projects) ===
OPENAI_API_KEY=sk-...
TELEGRAM_BOT_TOKEN=...
# Optional:
# WHATSAPP_TOKEN=...
# WHATSAPP_PHONE_NUMBER_ID=...
```

These are NOT used by docker-compose directly — they are stored here for
reference. Actual credentials are configured inside n8n and Dify web UIs.

### Step 3: Configure n8n for Production Webhooks

The lab n8n is already configured with:

- `N8N_HOST=n8n.<domain>`
- `N8N_PROTOCOL=https`
- `WEBHOOK_URL=https://n8n.<domain>/`

This is correct for receiving Telegram and WhatsApp webhooks over HTTPS.

**Verify in n8n settings** (web UI → Settings):

- Webhook URL shows `https://n8n.<domain>/`
- Timezone matches the server timezone

### Step 4: Chat Logging Database

Demo 1 logs conversations to a `chat_logs` table. The lab stack includes
a shared PostgreSQL container (`demo-db`) for demo projects.

> **Note:** n8n itself uses SQLite by default. This is fine for demo
> presentations. The `demo-db` is used for application data (chat logs,
> analytics), not for n8n internals.

Create the `reborn` database and initialize the schema:

```bash
# Create a dedicated database for reborn inside demo-db
docker exec -i demo-db psql -U demo -d demo -c "CREATE DATABASE reborn;"

# Initialize the chat_logs table
docker exec -i demo-db psql -U demo -d reborn < \
  ~/reborn-ai-demo/demos/01-chat-assistant/db/init-chat-logs.sql
```

**n8n PostgreSQL credential** (for workflows that write chat logs):

| Setting | Value |
|---------|-------|
| Host | `demo-db` |
| Port | `5432` |
| Database | `reborn` |
| User | `demo` |
| Password | `DEMO_DB_PASSWORD` from `.env` |

### Step 5: Import n8n Workflows

1. Open `https://n8n.<domain>`
2. Go to **Settings → Credentials** and add:
   - **Dify API**: Base URL `https://dify.<domain>`, API key from Dify app
   - **PostgreSQL**: Host `demo-db`, database `reborn`, user `demo`, password from `.env`
   - **Telegram**: Bot token from BotFather
   - **OpenAI** (optional): API key for direct OpenAI calls
3. Import workflows:
   - `demos/01-chat-assistant/n8n-workflows/telegram-chat.json`
   - `demos/01-chat-assistant/n8n-workflows/whatsapp-chat.json`
4. Update node credentials in each workflow
5. Activate workflows

### Step 6: Configure Dify Knowledge Base

1. Open `https://dify.<domain>`
2. Complete initial setup wizard (create admin account)
3. Add model providers:
   - **Ollama**: Base URL `http://ollama-compose:11434`, add `llama3.2` and `nomic-embed-text`
   - **OpenAI** (optional): API key for gpt-4o-mini
4. Create Knowledge Base:
   - Upload 5 documents from `demos/01-chat-assistant/knowledge-base/`
   - Select embedding model (`nomic-embed-text` via Ollama or OpenAI)
5. Create Chat App:
   - Attach the Knowledge Base
   - Set system prompt from `demos/01-chat-assistant/prompts/system-prompt.md`
   - Select LLM model (gpt-4o-mini or llama3.2)
   - Publish and get API key

### Step 7: Set Up Telegram Bot Webhook

1. Create a bot via [@BotFather](https://t.me/BotFather) on Telegram
2. Get the bot token
3. Configure the webhook URL to point to your n8n workflow:

```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -d "url=https://n8n.<domain>/webhook/telegram-chat"
```

### Step 8: Enable Langfuse Tracing (Optional)

Connect Dify to Langfuse for LLM observability:

1. Open `https://trace.<domain>`, create account and project
2. Create API keys (Public + Secret)
3. In Dify: **Settings → Monitoring → Langfuse**
   - Host: `https://trace.<domain>`
   - Public Key: `pk-...`
   - Secret Key: `sk-...`

## Verification Checklist

- [ ] Dify accessible at `https://dify.<domain>`
- [ ] Dify Knowledge Base created with 5 documents
- [ ] Dify Chat App configured and published
- [ ] n8n accessible at `https://n8n.<domain>`
- [ ] n8n credentials configured (Dify, PostgreSQL, Telegram)
- [ ] n8n Telegram workflow imported and activated
- [ ] Telegram bot responds to messages
- [ ] Chat logs appear in PostgreSQL `chat_logs` table
- [ ] Langfuse traces visible (if configured)

## Architecture on AI Lab

```text
Internet
  │
  ├── HTTPS :443
  │
  ▼
Traefik (reverse proxy + TLS)
  ├── dify.<domain>    → Dify (AI chatbot + RAG)
  ├── n8n.<domain>     → n8n (webhook receiver + orchestration)
  ├── flow.<domain>    → Flowise (available for future demos)
  └── trace.<domain>   → Langfuse (LLM observability)
                              │
                     ai-net (Docker network)
                              │
              ┌───────────────┼───────────────┐
              │               │               │
        ollama-compose   qdrant-compose     demo-db
        (LLM inference)  (vector store)   (demo projects)
```

## Troubleshooting

### Telegram webhook not receiving messages

- Verify webhook is set: `curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo`
- Check n8n workflow is active (not paused)
- Check n8n logs: `docker logs n8n --tail 50`
- Verify TLS certificate is valid: `curl -v https://n8n.<domain>/`

### Dify API returns 401

- Verify the API key in n8n matches the Dify app API key
- Check if the Dify app is published (not draft)
- URL should be `https://dify.<domain>/v1/chat-messages`

### Chat logs not appearing in PostgreSQL

- Verify PostgreSQL credentials in n8n
- Check the Code node in n8n workflow for correct connection string
- Run: `docker exec -i demo-db psql -U demo -d reborn -c "SELECT count(*) FROM chat_logs;"`

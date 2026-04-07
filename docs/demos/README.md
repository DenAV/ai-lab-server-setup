# Demo Project Deployment Guides

Step-by-step guides for deploying client demo projects on the AI Lab platform stack.

## Available Guides

| Project | Description | Services | Guide |
|---------|-------------|----------|-------|
| reborn-ai-demo | AI automation for service center (chatbot, RAG, workflows) | Dify, n8n, Ollama, PostgreSQL | [reborn-ai-demo.md](reborn-ai-demo.md) |

## General Workflow

1. Provision server with `setup.sh` and deploy platform stack (`docker compose up -d`)
2. Configure AI platforms via web UI (model providers, knowledge bases, apps)
3. Import n8n workflows and set up credentials
4. Configure external integrations (Telegram bots, webhook URLs)
5. Validate with the project-specific checklist

## Common Prerequisites

- Platform stack running and accessible via HTTPS
- Domain with DNS A-records pointing to the server (wildcard `*.domain` recommended)
- External API keys ready (OpenAI, Telegram, etc.)
- Familiarity with [integration guide](../integration-guide.md) for internal service URLs

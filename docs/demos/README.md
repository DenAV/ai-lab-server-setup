# Demo project deployment workflow

How to deploy a demo project on the AI Lab platform stack.

## General workflow

1. Provision server with `setup.sh` and deploy platform stack (`docker compose up -d`)
1. Clone the demo project onto the server
1. Create a dedicated database in `demo-db` for the project
1. Configure AI platforms via web UI (model providers, knowledge bases, apps)
1. Import n8n workflows and set up credentials
1. Configure external integrations (Telegram bots, webhook URLs)
1. Validate with the project-specific checklist

## Common prerequisites

- Platform stack running and accessible via HTTPS
- Domain with DNS A-records pointing to the server (wildcard `*.domain` recommended)
- External API keys ready (OpenAI, Telegram, etc.)
- Familiarity with [integration guide](../integration-guide.md) for internal service URLs

## Where to find project-specific guides

Each demo project keeps its own deployment guide in a `deploy/` directory
inside the project repository. This avoids leaking client-specific details
into the public platform repo.

Example structure inside a demo project:

```text
demo-project/
  deploy/
    ai-lab-deploy.md     # How to deploy on AI Lab server
  infrastructure/
    docker-compose.yml   # Standalone local development stack
    .env.example
```

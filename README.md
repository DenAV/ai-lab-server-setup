# AI Lab Server Setup

Universal provisioning scripts for AI/DevOps lab environments on **Ubuntu 24.04**.

One script turns a fresh server into a fully configured AI lab with Docker, Ollama,
Qdrant, Python venv, firewall, and SSH hardening. Optionally deploy a full platform
stack — Dify, Flowise, n8n, Langfuse, and Traefik — with a single `docker compose up`.
Works with any cloud provider or bare metal — not tied to a specific platform.

## System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB (base only) | 8 GB (full platform stack) |
| Disk | 40 GB | 80 GB |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

**Hetzner Cloud equivalents:**

| Type | vCPU | RAM | Use Case |
|------|------|-----|----------|
| CPX22 | 2 | 4 GB | Base setup only (no Dify, no LLM models) |
| **CPX32** | **4** | **8 GB** | **Full stack + small LLM (recommended)** |
| CPX42 | 8 | 16 GB | Full stack + larger LLM models |

## Quick Start

### Option A: Cloud-Init (Fully Automatic)

Pass `examples/cloud-config.yml` as user-data when creating a VM.
Cloud-init clones this repo and runs `setup.sh` automatically.

```bash
# Copy and customize the template
cp examples/cloud-config.yml cloud-config.yml
nano cloud-config.yml  # add your SSH public key

# Create VM (example: Hetzner Cloud)
hcloud server create \
  --name ai-lab \
  --type cpx32 \
  --image ubuntu-24.04 \
  --user-data-from-file cloud-config.yml
```

Wait 3-5 minutes, then `ssh lab@<server-ip>`.

### Option B: Clone and Run

```bash
ssh root@<server-ip>
git clone https://github.com/DenAV/ai-lab-server-setup.git /home/lab/ai-lab-server-setup
bash /home/lab/ai-lab-server-setup/setup.sh
```

### Option C: Pipe Over SSH

```bash
ssh root@<server-ip> 'bash -s' < setup.sh
```

The script auto-clones the repo for config files if not running from a local copy.

## What Gets Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| Docker Engine | latest | Container runtime |
| Ollama | latest | Local LLM inference |
| Qdrant | v1.12.1 | Vector database |
| Python 3.12 | system | Python environment with venv |
| UFW | system | Firewall (SSH, HTTP, HTTPS) |
| Fail2ban | system | Brute-force protection |

Default Ollama models pulled in background: `llama3.2`, `nomic-embed-text`.

## Files

| File | Description |
|------|-------------|
| [setup.sh](setup.sh) | Main setup script — run on any fresh Ubuntu 24.04 |
| [config/fail2ban.conf](config/fail2ban.conf) | Fail2ban jail configuration |
| [config/bash_aliases](config/bash_aliases) | Shell shortcuts for lab user |
| [docker-compose.yml](docker-compose.yml) | AI platform stack (Dify, Flowise, n8n, Ollama, Qdrant, Langfuse, Traefik) |
| [docker-compose.workers.yml](docker-compose.workers.yml) | Optional internal worker services for n8n workflows |
| [.env.example](.env.example) | Environment variables for docker-compose |
| [scripts/generate-env.sh](scripts/generate-env.sh) | Generate .env with auto-generated secrets (only domain + email needed) |
| [scripts/validate.sh](scripts/validate.sh) | Post-setup health check |
| [scripts/collect-diagnostics.sh](scripts/collect-diagnostics.sh) | Collect logs and configs into a zip for support |
| [examples/cloud-config.yml](examples/cloud-config.yml) | Cloud-init template (works with any provider) |
| [docs/](docs/) | Detailed setup guides and architecture decision records |
| [docs/update-server.md](docs/update-server.md) | How to apply repo changes to a running server |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and solutions |

## AI Platform Stack (Optional)

After running `setup.sh`, deploy the full platform stack:

```bash
cd ~/ai-lab-server-setup

# Generate .env with auto-generated secrets (only domain + email needed)
bash scripts/generate-env.sh example.com user@example.com

# Or interactively:
bash scripts/generate-env.sh

# Start all services
docker compose up -d

# View generated credentials
cat .secrets
```

Services included:

| Service | Subdomain | Purpose | Guide |
|---------|-----------|---------|-------|
| Traefik | — | Reverse proxy with automatic TLS | [setup](docs/setup-traefik.md) |
| Dify | `dify.<domain>` | AI application platform | [setup](docs/setup-dify.md) |
| Flowise | `flow.<domain>` | Visual AI agent builder | [setup](docs/setup-flowise.md) |
| n8n | `n8n.<domain>` | Workflow automation | [setup](docs/setup-n8n.md) |
| Ollama | internal | Local LLM runtime | [setup](docs/setup-ollama.md) |
| Qdrant | internal | Vector database | [setup](docs/setup-qdrant.md) |
| Langfuse | `trace.<domain>` | LLM observability | [setup](docs/setup-langfuse.md) |
| Demo DB | internal | Shared PostgreSQL for demo projects | — |

Optional internal workers can be started with an extra compose file:

```bash
docker compose -f docker-compose.yml -f docker-compose.workers.yml up -d --build
```

Available workers:

| Service | URL | Purpose | Guide |
|---------|-----|---------|-------|
| ffmpeg-worker | `http://ffmpeg-worker:8080` | Audio/video conversion for n8n workflows | [setup](docs/setup-ffmpeg-worker.md) |

## Deploying demo projects

The lab serves as infrastructure for AI demo presentations and quick
agent assembly. Any project that uses Dify, n8n, Ollama, or PostgreSQL can
be deployed on top of the running platform stack.

**Common requirements for demo projects:**

- External API keys (OpenAI, Telegram, etc.) — configure in platform UIs, not in `.env`
- HTTPS webhook URLs — provided by Traefik automatically
- PostgreSQL for chat/data logging — use the shared `demo-db` container (create a database per project)
- Dify apps and Knowledge Bases — created via Dify web UI

Each demo project should include its own deployment guide in a `deploy/`
directory with platform-specific instructions. See
[docs/demos/](docs/demos/) for the general deployment workflow.

## Configuration

Override defaults via environment variables before running `setup.sh`:

```bash
export LAB_USER="myuser"
export TIMEZONE="America/New_York"
export QDRANT_VERSION="v1.13.0"
export OLLAMA_MODELS="llama3.2 mistral nomic-embed-text"
./setup.sh
```

| Variable | Default | Description |
|----------|---------|-------------|
| `LAB_USER` | `lab` | Non-root user to create |
| `TIMEZONE` | `Europe/Berlin` | Server timezone |
| `QDRANT_VERSION` | `v1.12.1` | Qdrant Docker image tag |
| `OLLAMA_MODELS` | `llama3.2 nomic-embed-text` | Models to pull (space-separated) |

## Validation

Check that everything is working:

```bash
~/ai-lab-server-setup/scripts/validate.sh
# or via alias:
lab-validate
```

## Security

- Root SSH login disabled after setup
- Password authentication disabled (key-only)
- UFW firewall: only SSH (22), HTTP (80), HTTPS (443)
- Fail2ban protects SSH (3 attempts, 1h ban)
- All secrets in `.env` (gitignored, never committed)

> **WARNING**: `setup.sh` disables root SSH access. Make sure you can login as the
> lab user before closing your root session.

## License

[MIT](LICENSE)

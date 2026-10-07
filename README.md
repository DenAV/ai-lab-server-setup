# AI Lab Server Setup

Universal provisioning scripts for AI/DevOps lab environments on **Ubuntu 24.04**.

One script turns a fresh server into a fully configured AI lab with Docker,
Qdrant, Python venv, firewall, and SSH hardening. Optionally deploy a full platform
stack — Dify, n8n, OpenClaw, LiteLLM, Langfuse, Yopass, and Traefik — through selectable
Docker Compose profiles.
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
| CPX22 | 2 | 4 GB | Base setup only (no Dify, no local models) |
| **CPX32** | **4** | **8 GB** | **Full stack with cloud models (recommended)** |
| CPX42 | 8 | 16 GB | Full stack + larger LLM models |

See [Resource Baselines](docs/reference/resource-baselines.md) for the measured idle footprint,
host-class evidence, and sizing limitations. Local-model capacity remains model-specific.

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
| Qdrant | v1.12.1 | Vector database |
| Python 3.12 | system | Python environment with venv |
| UFW | system | Firewall (SSH, HTTP, HTTPS) |
| Fail2ban | system | Brute-force protection |

## Files

| File | Description |
|------|-------------|
| [setup.sh](setup.sh) | Main setup script — run on any fresh Ubuntu 24.04 |
| [config/fail2ban.conf](config/fail2ban.conf) | Fail2ban jail configuration |
| [config/bash_aliases](config/bash_aliases) | Shell shortcuts for lab user |
| [config/components.yml](config/components.yml) | Component inventory and dependency contracts |
| [config/litellm-config.yml](config/litellm-config.yml) | Internal LiteLLM model aliases and logging controls |
| [config/litellm-contracts.yml](config/litellm-contracts.yml) | Versioned LiteLLM compatibility and acceptance contracts |
| [docker-compose.yml](docker-compose.yml) | Profile-based AI platform stack with mandatory Traefik |
| [docker-compose.workers.yml](docker-compose.workers.yml) | Optional internal worker services for n8n workflows |
| [compose.openclaw-cli.yml](compose.openclaw-cli.yml) | Optional Docker CLI overlay for an existing rootless OpenClaw sandbox |
| [compose.traefik-cloudflare.yml](compose.traefik-cloudflare.yml) | Optional Cloudflare DNS-01 overlay for Traefik certificates |
| [.env.example](.env.example) | Environment variables for docker-compose |
| [scripts/generate-env.sh](scripts/generate-env.sh) | Generate .env with auto-generated secrets (only domain + email needed) |
| [scripts/validate.sh](scripts/validate.sh) | Post-setup health check |
| [scripts/collect-diagnostics.sh](scripts/collect-diagnostics.sh) | Collect logs and configs into a zip for support |
| [scripts/validate-component-catalog.py](scripts/validate-component-catalog.py) | Detect catalog and Compose drift |
| [scripts/validate-compose-presets.py](scripts/validate-compose-presets.py) | Verify resolved services for each preset |
| [scripts/validate-litellm-contracts.py](scripts/validate-litellm-contracts.py) | Validate LiteLLM client and provider contracts |
| [examples/cloud-config.yml](examples/cloud-config.yml) | Cloud-init template (works with any provider) |
| [docs/](docs/) | Detailed setup guides and architecture decision records |
| [docs/project/TODO.md](docs/project/TODO.md) | Actionable work for the modular stack constructor |
| [docs/project/ROADMAP.md](docs/project/ROADMAP.md) | Delivery phases for selectable deployment profiles |
| [docs/operations/update-server.md](docs/operations/update-server.md) | How to apply repo changes to a running server |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and solutions |

## AI Platform Stack (Optional)

After running `setup.sh`, choose the profiles for a supported preset. Phase 1 stores the
preset definitions in `config/components.yml`; the interactive selector arrives in Phase 2.

```bash
cd ~/ai-lab-server-setup

# Generate .env with auto-generated secrets (only domain + email needed)
bash scripts/generate-env.sh example.com user@example.com

# Or interactively:
bash scripts/generate-env.sh

# Example: start the n8n-cloud preset
COMPOSE_PROFILES=n8n,litellm docker compose up -d

# View generated credentials
cat .secrets
```

Services included:

| Service | Subdomain | Purpose | Guide |
|---------|-----------|---------|-------|
| Traefik | — | Reverse proxy with automatic TLS | [setup](docs/platforms/setup-traefik.md) |
| Dify | `dify.<domain>` | AI application platform | [setup](docs/platforms/setup-dify.md) |
| n8n | `n8n.<domain>` | Workflow automation | [setup](docs/platforms/setup-n8n.md) |
| OpenClaw | SSH tunnel only | Personal AI assistant | [setup](docs/platforms/setup-openclaw.md) |
| LiteLLM | configurable HTTPS subdomain | Model gateway and virtual-key boundary | [setup](docs/platforms/setup-litellm.md) |
| Ollama | optional internal service | Local LLM runtime (`local-model` profile) | [setup](docs/platforms/setup-ollama.md) |
| Qdrant | internal | Vector database | [setup](docs/platforms/setup-qdrant.md) |
| Langfuse | `trace.<domain>` | LLM observability | [setup](docs/platforms/setup-langfuse.md) |
| Demo DB | internal | Shared PostgreSQL for demo projects | — |
| Yopass | `yopass.<domain>` | End-to-end encrypted secret sharing | [setup](docs/platforms/setup-yopass.md) |

Flowise was retired from this stack. See [ADR-0007](docs/adr/0007-retire-flowise.md)
for the reason and the commit containing its former setup guide.

Optional internal workers can be started with an extra compose file:

```bash
COMPOSE_PROFILES=n8n,ffmpeg-worker docker compose \
  -f docker-compose.yml -f docker-compose.workers.yml up -d --build
```

Available workers:

| Service | URL | Purpose | Guide |
|---------|-----|---------|-------|
| ffmpeg-worker | `http://ffmpeg-worker:8080` | Audio/video conversion for n8n workflows | [setup](docs/platforms/setup-ffmpeg-worker.md) |

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

Override host provisioning defaults via environment variables before running `setup.sh`:

```bash
export LAB_USER="myuser"
export TIMEZONE="America/New_York"
./setup.sh
```

| Variable | Default | Description |
|----------|---------|-------------|
| `LAB_USER` | `lab` | Non-root user to create |
| `TIMEZONE` | `Europe/Berlin` | Server timezone |

Select a preset by setting its resolved profiles in `.env` or for one command:

| Preset | `COMPOSE_PROFILES` |
|--------|--------------------|
| `n8n-cloud` | `n8n,litellm` |
| `dify-cloud` | `dify,qdrant,litellm` |
| `openclaw` | `openclaw` |

Traefik has no profile and always resolves. Add `local-model` only when explicitly
enabling Ollama. See [Compose Profiles](docs/operations/compose-profiles.md) for component profiles,
dependency closures, and commands.

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

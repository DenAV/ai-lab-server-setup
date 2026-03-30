# AI Lab Server Setup

Universal provisioning scripts for AI/DevOps lab environments on **Ubuntu 24.04**.

One script turns a fresh server into a fully configured AI lab with Docker, Ollama,
Qdrant, Python venv, firewall, and SSH hardening. Works with any cloud provider
or bare metal — not tied to a specific platform.

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
  --type cpx22 \
  --image ubuntu-24.04 \
  --user-data-from-file cloud-config.yml
```

Wait 3-5 minutes, then `ssh lab@<server-ip>`.

### Option B: Clone and Run

```bash
ssh root@<server-ip>
git clone https://github.com/DenAV/ai-lab-server-setup.git /opt/ai-lab-server-setup
/opt/ai-lab-server-setup/setup.sh
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
| [docker-compose.yml](docker-compose.yml) | AI platform stack (Flowise, n8n, Ollama, Qdrant, Langfuse, Traefik) |
| [.env.example](.env.example) | Environment variables for docker-compose |
| [scripts/validate.sh](scripts/validate.sh) | Post-setup health check |
| [examples/cloud-config.yml](examples/cloud-config.yml) | Cloud-init template (works with any provider) |

## AI Platform Stack (Optional)

After running `setup.sh`, deploy the full platform stack:

```bash
cd ~/ai-lab-server-setup
cp .env.example .env
nano .env            # set domain, passwords, API keys
docker compose up -d
```

Services included:

| Service | Subdomain | Purpose |
|---------|-----------|---------|
| Traefik | — | Reverse proxy with automatic TLS |
| Flowise | `flow.<domain>` | Visual AI agent builder |
| n8n | `n8n.<domain>` | Workflow automation |
| Ollama | internal | Local LLM runtime |
| Qdrant | internal | Vector database |
| Langfuse | `trace.<domain>` | LLM observability |

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

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- Flowise service, Docker volume declaration, generated credentials, validation, and active setup instructions. See [ADR-0007](docs/adr/0007-retire-flowise.md) for the archived guide's commit.

### Added

- Product-level Compose profiles, initial preset closures, and resolved-service validation
- Internal LiteLLM Proxy `v1.103.2` with a dedicated PostgreSQL database and secure defaults
- Measured idle resource baseline, component metrics, and evidence-qualified VPS sizing
- Versioned LiteLLM client/provider contracts and acceptance-test gates
- Machine-readable component catalog with Compose drift validation in CI
- Guidance for dedicated least-privilege credentials in persistent OpenClaw SSH storage
- Optional rootless OpenClaw sandbox client image, Docker CLI overlay, and operating guide
- ADR-0008, project TODO, and roadmap for a modular stack constructor with presets,
  a custom component checklist, dependency resolution, and resource checks
- OpenClaw Gateway container, isolated network, persistent state, health check, and loopback-only access
- Optional `local-model` Compose profile for container-only Ollama deployments
- `CONSOLE_API_URL`, `CONSOLE_WEB_URL`, `APP_API_URL`, `APP_WEB_URL` to `dify-api` in docker-compose (fixes CORS 401 errors)
- `VECTOR_STORE=qdrant` and `QDRANT_URL` to `dify-api` and `dify-worker` in docker-compose
- `docs/operations/upgrade-dify.md` — storage permissions and nginx restart steps
- Dify troubleshooting entries: CORS 401, vector store, file upload permissions, 502 after restart
- `docs/demos/` — separate folder for demo project deployment guides
- `docs/demos/reborn-ai-demo.md` — deployment guide for reborn-ai-demo on AI Lab
- `docs/operations/update-server.md` — how to apply repo changes to a running server
- `demo-db` service in docker-compose — shared PostgreSQL for demo projects
- `DEMO_DB_PASSWORD` in `.env.example` and `generate-env.sh`
- "Deploying Demo Projects" section in README with project deployment workflow
- `setup.sh` — universal setup script for Ubuntu 24.04 (any cloud or bare metal)
- `config/fail2ban.conf` — Fail2ban jail configuration
- `config/bash_aliases` — shell shortcuts for lab user
- `docker-compose.yml` — AI platform stack (Dify, Flowise, n8n, Ollama, Qdrant, Langfuse, Traefik)
- `.env.example` — environment variables template for docker-compose
- `scripts/validate.sh` — post-setup health check
- `examples/cloud-config.yml` — minimal cloud-init template (provider-agnostic)
- `docs/` — detailed product setup guides (Ollama, Qdrant, Traefik, Dify, Flowise, n8n, Langfuse)
- `docs/adr/` — architecture decision records (6 ADRs + template)
- `config/dify-nginx.conf` — nginx routing for Dify API and web frontend (variable-based proxy_pass for DNS re-resolution)

### Changed

- Organized documentation into platform, integration, operations, project, and reference sections with link validation
- Replaced legacy standalone Qdrant commands with authenticated Compose-profile operations
- Pin n8n to 2.40.7 and Qdrant to v1.19.1, and remove the unused setup-time Qdrant override
- Removed native Ollama installation from `setup.sh`; local inference now uses only the optional Compose service
- OpenClaw provider credentials are stored through interactive ChatGPT OAuth and OpenCode Go auth instead of Compose environment variables

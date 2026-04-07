# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `docs/demos/` — separate folder for demo project deployment guides
- `docs/demos/reborn-ai-demo.md` — deployment guide for reborn-ai-demo on AI Lab
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
- `config/dify-nginx.conf` — nginx routing for Dify API and web frontend

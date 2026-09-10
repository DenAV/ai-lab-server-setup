# AGENTS.md

## Scope

- This repo provisions and operates an Ubuntu 24.04 AI lab server, not an application monorepo.
- Main entrypoints: `setup.sh` for host provisioning, `docker-compose.yml` for the platform stack, `docker-compose.workers.yml` for optional internal workers, and `scripts/validate.sh` for live health checks.
- Use relevant OpenCode skills before changing live infrastructure: `dev-docker` for compose/container work, `dev-deployment` for rollout/rollback, `ai-n8n` or `ai-dify` for platform-specific workflow/app issues, and `agent-systematic-debugging` for failures.

## Local Verification

- Run the same offline check as CI with `bash tests/test_repo.sh`; it validates required files, Bash syntax, ShellCheck when installed, YAML, compose config when Docker exists, `.env.example` coverage, secret patterns, and doc links.
- CI additionally runs `bash -n setup.sh scripts/generate-env.sh scripts/validate.sh scripts/collect-diagnostics.sh`, `shellcheck --severity=error ...`, and `yamllint -d relaxed docker-compose.yml examples/cloud-config.yml`.
- This workspace may not have Docker installed; `tests/test_repo.sh` skips compose validation when Docker is unavailable.

## Live Server Workflow

- The agent may have SSH access to the running server; use it for live diagnostics instead of guessing from local files when a user reports runtime behavior.
- Server-side repo path is expected to be `~/ai-lab-server-setup` for the `lab` user.
- Typical live checks: `ssh lab@<server> 'cd ~/ai-lab-server-setup && docker compose ps'`, targeted `docker compose logs --tail=50 <service>`, and `~/ai-lab-server-setup/scripts/validate.sh` or `lab-validate`.
- For a support bundle, run `bash ~/ai-lab-server-setup/scripts/collect-diagnostics.sh`; it redacts common secrets, but still review before sharing.

## Safety Rules

- Never re-run `scripts/generate-env.sh` on an existing server unless the user explicitly accepts rotating all stack secrets; it overwrites `.env` and writes `.secrets`.
- When `.env.example` gains variables, append only the missing values to the live `.env`; do not regenerate the whole file.
- Do not use `docker system prune --volumes`; repo docs warn this may delete service data.
- Before major Dify or n8n upgrades, check release notes and back up volumes; `docs/upgrade-dify.md` is the existing Dify major-upgrade path.
- Do not commit `.env`, `.secrets`, SSH keys, PEM/key files, or generated `cloud-config.yml`; root `.gitignore` intentionally ignores them.

## Stack Gotchas

- `setup.sh` disables root SSH login and password auth, then restarts `ssh` because Ubuntu 24.04 uses `ssh.service`, not `sshd.service`.
- Docker 29+ and Traefik need the `DOCKER_MIN_API_VERSION=1.24` systemd override; both `setup.sh` and `TROUBLESHOOTING.md` document this.
- `traefik-public` is explicitly named in compose; changing that network name causes Traefik routing failures.
- The Qdrant Compose container is named `qdrant-compose`, while some older aliases/live validation still reference standalone `qdrant`; verify actual `docker compose ps` before changing Qdrant logic.
- Ollama is container-only and guarded by the `local-model` Compose profile; the default cloud-model stack must not start it.
- OpenClaw publishes its Gateway only on host loopback port `18789`; access it through an SSH tunnel and never mount the Docker socket without an explicit sandbox design review.
- Optional `ffmpeg-worker` mounts `/home/lab/client-conversation-analyzer-data` and limits file access through `N8N_RESTRICT_FILE_ACCESS_TO=/data/cca`.

## Style

- Shell and YAML use 2-space indentation per `.editorconfig`.
- Prefer `bash script.sh` in docs/examples; Git may not preserve executable bits after clone.

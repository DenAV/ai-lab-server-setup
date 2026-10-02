# OpenClaw Rootless Sandbox Client

This optional overlay requires an existing rootless Docker daemon and a host-specific
Compose override mounting its socket at `/run/openclaw-sandbox/docker.sock`, with the
socket group added to OpenClaw. Never substitute the rootful `/var/run/docker.sock`.

`Dockerfile.openclaw-sandbox` adds only Docker CLI to OpenClaw 2026.9.4. Both source
images are pinned by digest. Update these pins and the derived image tag together on
upgrade: this overlay overrides the base service image version.

## Setup

Build from the repository directory without sending local files as build context:

```bash
docker build -t openclaw-sandbox-client:2026.9.4-docker29.8.0 - < Dockerfile.openclaw-sandbox
```

The daemon must see workspace and generated skills directories at the same absolute
paths as the Gateway. Inspect existing paths before changing permissions. Create the
skills directory using verified Gateway UID and socket group GID:

```bash
sudo install -d -m 0755 /home/node /home/node/.openclaw /home/node/.openclaw/sandbox
sudo install -d -o <gateway-uid> -g <socket-group-gid> -m 2770 \
  /home/node/.openclaw/sandbox/skills-workspaces
```

Only generated skills are shared; do not mount the authentication state into sandboxes.
Back up `.env` with restricted permissions and append the overlay after the existing
host-specific override:

```dotenv
COMPOSE_FILE=docker-compose.yml:compose.digital-office.yml:compose.openclaw-cli.yml
```

From the repository directory:

```bash
docker compose config --quiet
docker compose up -d --no-deps --no-build openclaw
```

## Verification

Wait for `healthy` before testing agent calls:

```bash
docker inspect openclaw --format '{{.State.Health.Status}}'
docker compose exec openclaw docker info --format '{{json .SecurityOptions}}'
docker compose exec openclaw docker image inspect openclaw-sandbox:bookworm-slim
docker compose exec openclaw node dist/index.js config validate
docker compose exec openclaw node dist/index.js sandbox list
```

The daemon must report `rootless`. A Node.js `/_ping` test alone does not validate CLI
availability, daemon selection, or host bind paths. Complete a harmless agent turn and
inspect the resulting sandbox's running state, mounts, isolation, and resource limits.

Codex can reject execution when effective `tools.exec.mode=deny`. This is a separate
runtime/policy conflict. Do not disable sandboxing or relax execution approvals merely
to pass diagnostics; choose a compatible runtime or approve a specific policy change.

## Rollback

Remove only `compose.openclaw-cli.yml` from `COMPOSE_FILE` and recreate OpenClaw.
This restores the previous image and mounts, including its missing-CLI limitation.
Preserve state volumes and workspace data.

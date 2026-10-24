# OpenClaw Rootless Gateway and Sandbox

Run the Gateway and its sandbox containers on the **same rootless Docker daemon**.
OpenClaw 2026.9.5 and newer verifies the Gateway container through that daemon before
projecting workspace binds. A rootful Compose Gateway with a separate rootless sandbox
daemon fails sandbox provisioning. Never substitute the rootful Docker socket.

`compose.openclaw-rootless.yml` is a standalone Compose project, not an overlay on the
rootful stack. `Dockerfile.openclaw-sandbox` adds Docker CLI to the pinned OpenClaw
`2026.10.6` image. The Gateway runs as root **inside the rootless user namespace** so its
host identity matches the socket owner. It does not receive host root or a rootful socket.
Update the pinned base digest and the derived image tag together for future upgrades.

OpenClaw 2026.10.6 requires Node.js 24.22.1+ on the Node 24 line. The pinned
Gateway image supplies 24.22.1. Before the live upgrade, a checksum-verified cold
archive was restored into an isolated directory and Doctor migrated all six agent
databases from v24 to v25 with networking disabled. Keep that archive: the old
2026.9.9 image must not open upgraded databases without a separately approved restore.

Post-upgrade checks passed for Codex responses, node execution, Codex Hosted Search,
Qwen embeddings through OpenRouter, scheduler access, and Telegram polling. The
upstream release removes the old system-owned weekly Skill collection review jobs;
it does not preserve them as ordinary weekly automations. Heartbeat remains 30 minutes.

Keep `TMPDIR=/home/node/.openclaw/tmp` in the Gateway environment. Model Setup creates
a temporary inference workspace under Node's temporary directory. Container-only
`/tmp` is not a valid sibling-sandbox source, so setup fails even when normal agent
workspaces are mounted correctly. The configured temporary directory is already
inside the state bind mount; no host `/tmp` mount or sandbox permission bypass is
needed. The `openclaw.chat` setup-inference path was verified after this change.

The Gateway is limited to 2 CPUs and 3 GiB RAM. `memswap_limit: 5g` preserves a
2 GiB swap allowance rather than increasing it implicitly with the RAM limit.
The previous 1 CPU/2 GiB limits throttled a simple test in 170 of 206 CPU periods
and put about 0.9 GiB into swap. Equivalent first/repeated no-tool agent turns
improved from 14.8/8.7 seconds to 6.9/2.7 seconds after the limit change; CLI wall
times also include local command startup. No model, thinking, or tool-policy changes
were needed. Monitor host headroom before increasing limits further on shared hosts.

The existing rootful OpenClaw container and its volumes remain stopped for recovery;
the normal rootful stack omits the `openclaw` profile and sets `OPENCLAW_RUNTIME=rootless`
in `.env`. Run `bash scripts/validate.sh` for checks across both daemons.

## Migrating an existing Gateway

Before a cutover, record the current image and health, and build the replacement image
on the rootless daemon. Stop only the old Gateway; take and verify a **cold** archive of
both `openclaw-data` and `openclaw-ssh`. Keep the old container, images, volumes, and
archives. Copy state and SSH data into restricted directories owned by the rootless
service account, and put only the Gateway token and rootless Compose settings in a
`0600` env file owned by that account (outside Git). Never regenerate `.env`.

The rootless env file needs `OPENCLAW_GATEWAY_TOKEN`, `OPENCLAW_ROOTLESS_DATA_DIR`,
`OPENCLAW_ROOTLESS_SOCKET`, and `TIMEZONE`. Under `OPENCLAW_ROOTLESS_DATA_DIR`, bind
`state` to `/home/node/.openclaw` and `ssh` to `/home/node/.ssh`. Existing workspaces
in `/srv/openclaw-office` remain shared: back up their ACLs first, then grant only the
rootless account the group-equivalent access it needs to traverse the configured
workspaces and sandbox directories, including default ACLs for future files. Do not
grant it access to unrelated private directories or the host's rootful Docker socket.

From the repository directory, run Compose as the rootless service user with its own
Docker socket and the protected env file:

```bash
sudo -u <service-user> env XDG_RUNTIME_DIR=/run/user/<uid> \
  DOCKER_HOST=unix:///run/user/<uid>/docker.sock \
  docker compose -f compose.openclaw-rootless.yml --env-file <rootless-env-file> config --quiet
sudo -u <service-user> env XDG_RUNTIME_DIR=/run/user/<uid> \
  DOCKER_HOST=unix:///run/user/<uid>/docker.sock \
  docker compose -f compose.openclaw-rootless.yml --env-file <rootless-env-file> \
  up -d --no-build openclaw
```

If migration or verification fails, preserve both installations and ask the operator
before restoring state or switching back. OpenClaw may have migrated database schemas;
reusing new state with the old image is not a safe rollback.

## Verification

Run the commands against the **rootless** Docker daemon. Check the version, health,
Control UI loopback port, configuration, security audit, and rootless socket:

```bash
docker inspect openclaw --format '{{.State.Health.Status}}'
docker port openclaw 18789/tcp
docker exec openclaw node dist/index.js --version
docker exec openclaw node dist/index.js config validate
docker exec openclaw node dist/index.js security audit --json
docker exec openclaw docker info --format '{{json .SecurityOptions}}'
curl -fsS http://127.0.0.1:18789/healthz
```

The daemon must report `rootless`. Complete a harmless Codex agent turn and a sandbox
shell-tool turn; verify the sandbox container is on the same daemon with network
isolation and without the state, SSH, or Docker socket mounts. Repeat the Gateway health
check after a restart to confirm persistence and restart behavior.

Codex can reject execution when effective `tools.exec.mode=deny`. This is a separate
runtime/policy conflict. Do not disable sandboxing or relax execution approvals merely
to pass diagnostics; choose a compatible runtime or approve a specific policy change.

## Recovery

Stop the rootless Gateway before recovery. Restore the matching pre-upgrade cold state
and SSH archives only with operator approval; the stopped rootful container and volumes
are retained as independent recovery inputs. Never use `docker compose down -v` here.

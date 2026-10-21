# OpenClaw Host Operator

The optional native `host-operator` node runs OpenClaw 2026.9.9 as the dedicated
`openclaw-operator` system account. The existing containerized Gateway connects to it
through native device pairing. Telegram and sandbox defaults are unchanged.

Only this host node joins the rootful `docker` group. Docker access is effectively
host-root authority even though the service does not run as root. The Gateway keeps
only its existing rootless socket; ordinary sandbox containers receive neither socket.

## Install

On the existing x86_64 Ubuntu host with a working rootless Gateway:

```bash
sudo bash scripts/setup-openclaw-operator.sh install
```

Set `OPENCLAW_GATEWAY_USER` when the rootless daemon belongs to a different account.
The installer verifies the pinned Node.js archive checksum, installs OpenClaw as an
unprivileged user before granting Docker access, and makes its runtime root-owned.
It uses a short-lived loopback setup code without printing it, confirms the paired
device identity, and starts `openclaw-operator.service`. No shared Gateway token is
stored in the operator service. Identity and credentials live in the protected
`/var/lib/openclaw-operator/.openclaw` directory. Automatic node updates are disabled.

Rerunning preserves credentials and approval policy and verifies connection plus
read-only `id` and `docker ps` calls through the Gateway. It does not reinstall an
existing runtime, rotate credentials, or automatically roll back on failure.

## Commands and approvals

The node advertises only `system.which`, `system.run.prepare`, `system.run`, and the
two exec-approval management commands. Browser sharing, MCP tool publication, and
session hosting are not enabled.

For agent `main`, exact `/usr/bin/id` and `/usr/bin/docker ps` calls are allowlisted.
Other commands require approval; missing or unavailable approval denies execution.
No path-only Docker allowlist is installed. Inspect approvals using the Gateway CLI:

```bash
openclaw nodes describe --node host-operator
openclaw approvals get --node host-operator
```

These commands refer to the CLI inside the existing Gateway; see the
[rootless runbook](openclaw-rootless-sandbox.md) for selecting its daemon.
Agent tool policy is an additional gate: pairing alone does not change a sandboxed
session's exec target. With operator approval, the live `main` agent allows `nodes`
in both its agent tool policy and its per-agent sandbox tool policy, and removes
`nodes` from both deny lists. Its exec settings are `host=node`, `node=host-operator`,
and `mode=ask`. Other agents retain their existing restrictions. The installer does
not automatically grant these agent permissions; back up the Gateway config before
applying them and preserve unrelated tool rules.

Real `main` Codex turns successfully invoked `nodes` and `node_exec` for `id` and
`docker ps`. The operator also confirmed successful `docker ps` through `node_exec`
from the existing Telegram chat. The Telegram approval UI for non-allowlisted commands
has not been verified. A sandbox status of `docker/all` and absence of
Docker inside the sandbox do not prevent execution through the separate `node_exec` tool.

The rootless Gateway memory limit is 2 GiB. A real agent turn exhausted the previous
1 GiB limit and triggered a kernel cgroup OOM kill. After increasing the limit, both
node-tool turns completed successfully; the rootful socket remains outside the Gateway.

## Operation and disabling host access

```bash
sudo systemctl status openclaw-operator.service
sudo systemctl restart openclaw-operator.service
sudo bash scripts/setup-openclaw-operator.sh disable
```

The disable action stops/disables the service, terminates remaining operator processes,
and removes Docker group membership. It preserves state and does not restart the
Gateway. For full enrollment removal, revoke the `node` role of the exact device ID in
`/var/lib/openclaw-operator/enrolled-device` using `openclaw devices revoke --device
<device-id> --role node` on the Gateway. Do not clear unrelated paired devices.

Disable/revocation actions must be explicitly requested by the operator. Installation
never performs them as an automatic rollback. Runtime files remain available for
inspection; do not delete credentials or state as part of a routine stop.

# OpenClaw Host Operator

The optional native `host-operator` node runs OpenClaw 2026.10.6 as the dedicated
`openclaw-operator` system account. The existing containerized Gateway connects to it
through native device pairing.

Neither this node nor the Gateway may access the rootful Docker socket. The operator
uses only OpenClaw's separate rootless daemon; other stack containers remain on the
rootful daemon. Ordinary sandbox containers receive neither socket. Do not replace
this separation with container-name filtering: unrestricted rootful Docker access
would also grant host-root authority.

## Install

On the existing x86_64 Ubuntu host with a working rootless Gateway:

```bash
sudo bash scripts/setup-openclaw-operator.sh install
```

Set `OPENCLAW_GATEWAY_USER` when the rootless daemon belongs to a different account.
The host must have `acl` installed. `OPENCLAW_OFFICE_DIR` defaults to
`/srv/openclaw-office` and must already exist.
The installer verifies the pinned Node.js archive checksum, installs OpenClaw as an
unprivileged user before granting Docker access, and makes its runtime root-owned.
It uses a short-lived loopback setup code without printing it, confirms the paired
device identity, and starts `openclaw-operator.service`. No shared Gateway token is
stored in the operator service. Identity and credentials live in the protected
`/var/lib/openclaw-operator/.openclaw` directory. Automatic node updates are disabled.

Rerunning stops the operator while updating its boundary, removes legacy rootful
Docker group membership, preserves credentials and approval policy, and verifies connection plus
read-only `id` and `docker ps` calls through the Gateway. It does not reinstall an
existing runtime, rotate credentials, or automatically roll back on failure.

Runtime installations are versioned under `/opt/openclaw-operator/releases/`.
The live 2026.10.6 service uses a root-owned systemd drop-in selecting its Node.js
24.22.1 and package paths. Its previous installation remains retained. Upgrades must
stop the operator and back up its credential state before migrating with the matching
Doctor. Do not run npm installation as a user that already has Docker authority;
prepare a candidate as an isolated build user, then make the files root-owned.
The 2026.10.6 node adds signed execution-context support; reapprove only the existing
device identity and previously approved command list, not unrelated pending nodes.

## Commands and approvals

The node advertises only `system.which`, `system.run.prepare`, `system.run`, and the
two exec-approval management commands. Browser sharing, MCP tool publication, and
session hosting are not enabled.

New installations allowlist exact `/usr/bin/id` and `/usr/bin/docker ps` calls.
The live, user-approved autonomous setup permits unattended commands from `main`
(`security=full`, `ask=off`) on this non-root node. This does not grant host root:
the service has an empty capability set, no privilege escalation, a protected host
filesystem/home directories, private temporary storage/devices, and writable access
only to its own state and the OpenClaw office directory. The rootless Docker socket
is reachable through a user-specific ACL, renewed after rootless daemon startup.
Its daemon can still modify resources owned by the rootless account, including
OpenClaw itself. This is not a guarantee against kernel/container vulnerabilities.
Inspect approvals using the Gateway CLI:

```bash
openclaw nodes describe --node host-operator
openclaw approvals get --node host-operator
```

These commands refer to the CLI inside the existing Gateway; see the
[rootless runbook](openclaw-rootless-sandbox.md) for selecting its daemon.
Agent tool policy is an additional gate: pairing alone does not change a sandboxed
session's exec target. The live main/worker agents use `host=sandbox`, `mode=full`,
outbound bridge networking, and writable container roots, with full native tool
profiles. Host work is explicit through the separate node, not the default target.
Sandbox workspaces remain isolated; return report contents to main or use supported
attachments instead of assuming cross-agent paths are shared. Elevated execution
remains disabled. The installer does not overwrite these Gateway policies.

Telegram admission is not owner authorization. Set `commands.ownerAllowFrom` to the
confirmed user identity, for example `telegram:<your-user-id>`, while retaining the
channel's admission allowlist. Otherwise owner-only tools such as `automations` can
be hidden from Telegram even when an admin CLI test succeeds. Never authorize all
senders with a wildcard. Use native `automations`, not host CLI scheduler commands.
For files, discover the full native message schema (`media`, `filename`,
`forceDocument`); a short text-only Codex helper does not imply Telegram lacks file
support. Verify the tool's delivery receipt.

The rootless Gateway has 2 CPUs and a 3 GiB RAM limit, with a 5 GiB combined
RAM-plus-swap limit (2 GiB swap allowance). The original 1 GiB limit caused a cgroup
OOM kill; 2 GiB restored node-tool execution but later caused memory pressure and
swapping under the larger runtime. Increasing from 1 CPU/2 GiB to 2 CPUs/3 GiB
reduced two synthetic no-tool response times from 20.2/13.4 seconds to 10.0/5.3
seconds. These are small diagnostic samples, not a latency guarantee. The rootful
socket remains outside the Gateway.

## Operation and disabling host access

```bash
sudo systemctl status openclaw-operator.service
sudo systemctl restart openclaw-operator.service
sudo bash scripts/setup-openclaw-operator.sh disable
```

The disable action stops/disables the service, terminates remaining operator processes,
and removes Docker-related group membership and the rootless socket ACL/drop-in.
It preserves state and does not restart the
Gateway. For full enrollment removal, revoke the `node` role of the exact device ID in
`/var/lib/openclaw-operator/enrolled-device` using `openclaw devices revoke --device
<device-id> --role node` on the Gateway. Do not clear unrelated paired devices.

Disable/revocation actions must be explicitly requested by the operator. Installation
never performs them as an automatic rollback. Runtime files remain available for
inspection; do not delete credentials or state as part of a routine stop.

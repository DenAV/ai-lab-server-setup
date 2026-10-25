#!/usr/bin/env bash
# Install a separate native node; never mount the rootful socket into the Gateway.
set -euo pipefail
umask 077

ACTION="${1:-install}"
OPERATOR=openclaw-operator
STATE=/var/lib/openclaw-operator
NODE_VERSION=24.22.1
OPENCLAW_VERSION=2026.10.6
RUNTIME=/opt/openclaw-operator/releases/${OPENCLAW_VERSION}
GATEWAY_USER="${OPENCLAW_GATEWAY_USER:-openclaw-sandbox}"
OFFICE_GROUP=openclaw-office
OFFICE_DIR="${OPENCLAW_OFFICE_DIR:-/srv/openclaw-office}"
SERVICE=openclaw-operator.service

[[ "${EUID}" = 0 ]] || { echo "Run with sudo." >&2; exit 1; }
case "${ACTION}" in install|disable) ;; *) echo "Usage: $0 [install|disable]" >&2; exit 1 ;; esac

if [[ "${ACTION}" = disable ]]; then
  systemctl disable --now "${SERVICE}"
  # Terminate any remaining user processes, including detached child commands.
  loginctl terminate-user "${OPERATOR}" 2>/dev/null || true
  pkill -KILL -u "${OPERATOR}" 2>/dev/null || true
  if id -nG "${OPERATOR}" | tr ' ' '\n' | grep -qx docker; then
    gpasswd -d "${OPERATOR}" docker
  fi
  if id -nG "${OPERATOR}" | tr ' ' '\n' | grep -qx "${OFFICE_GROUP}"; then
    gpasswd -d "${OPERATOR}" "${OFFICE_GROUP}"
  fi
  if id "${GATEWAY_USER}" >/dev/null 2>&1; then
    gateway_uid="$(id -u "${GATEWAY_USER}")"
    gateway_home="$(getent passwd "${GATEWAY_USER}" | cut -d: -f6)"
    rm -f "${gateway_home}/.config/systemd/user/docker.service.d/30-openclaw-operator-acl.conf"
    setfacl -x "u:${OPERATOR}" "/run/user/${gateway_uid}/docker.sock" 2>/dev/null || true
    setfacl -x "u:${OPERATOR}" "/run/user/${gateway_uid}" 2>/dev/null || true
    runuser -u "${GATEWAY_USER}" -- env XDG_RUNTIME_DIR="/run/user/${gateway_uid}" \
      systemctl --user daemon-reload
  fi
  echo "Operator stopped and Docker access removed. State retained; revoke its paired device separately."
  exit 0
fi

[[ "$(uname -m)" = x86_64 ]] || { echo "This installer requires x86_64." >&2; exit 1; }
for cmd in curl tar sha256sum python3 runuser systemctl getent setfacl gpasswd; do command -v "${cmd}" >/dev/null; done
GATEWAY_UID="$(id -u "${GATEWAY_USER}")"
GATEWAY_GROUP="$(id -gn "${GATEWAY_USER}")"
GATEWAY_HOME="$(getent passwd "${GATEWAY_USER}" | cut -d: -f6)"
ROOTLESS_SOCKET="/run/user/${GATEWAY_UID}/docker.sock"
[[ "${OFFICE_DIR}" = /* && -d "${OFFICE_DIR}" && -S "${ROOTLESS_SOCKET}" ]] || {
  echo "An absolute existing office directory and running rootless Docker are required." >&2
  exit 1
}
gateway() {
  runuser -u "${GATEWAY_USER}" -- env XDG_RUNTIME_DIR="/run/user/${GATEWAY_UID}" \
    docker -H "unix:///run/user/${GATEWAY_UID}/docker.sock" exec openclaw node dist/index.js "$@"
}
gateway --version
curl -fsS --max-time 10 http://127.0.0.1:18789/healthz >/dev/null

if ! id "${OPERATOR}" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "${STATE}" --shell /usr/sbin/nologin "${OPERATOR}"
fi
[[ "$(getent passwd "${OPERATOR}" | cut -d: -f6)" = "${STATE}" ]] || exit 1
if systemctl is-active --quiet "${SERVICE}"; then
  systemctl stop "${SERVICE}"
fi
if id -nG "${OPERATOR}" | tr ' ' '\n' | grep -qx docker; then
  gpasswd -d "${OPERATOR}" docker
fi
getent group "${OFFICE_GROUP}" >/dev/null || groupadd --system "${OFFICE_GROUP}"
usermod -aG "${OFFICE_GROUP}" "${OPERATOR}"
install -d -o "${OPERATOR}" -g "${OPERATOR}" -m 700 "${STATE}"
install -d -o root -g root -m 755 "${RUNTIME}"

if [[ ! -x "${RUNTIME}/node/bin/node" ]]; then
  temp="$(mktemp -d)"
  trap 'rm -rf -- "${temp}"' EXIT
  archive="node-v${NODE_VERSION}-linux-x64.tar.xz"
  curl -fsS "https://nodejs.org/dist/v${NODE_VERSION}/${archive}" -o "${temp}/${archive}"
  curl -fsS "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" -o "${temp}/SHASUMS256.txt"
  (cd "${temp}"; grep " ${archive}$" SHASUMS256.txt | sha256sum -c -)
  install -d -m 755 "${RUNTIME}/node"
  tar -xJf "${temp}/${archive}" --strip-components=1 -C "${RUNTIME}/node"
  chmod -R a+rX "${RUNTIME}/node"
fi
[[ "$("${RUNTIME}/node/bin/node" --version)" = "v${NODE_VERSION}" ]] || exit 1

if [[ ! -f "${RUNTIME}/app/node_modules/openclaw/openclaw.mjs" ]]; then
  # Install dependencies without rootful Docker authority or npm running as root.
  if id -nG "${OPERATOR}" | tr ' ' '\n' | grep -qx docker; then
    echo "Refusing npm install while operator has Docker access; disable it first." >&2
    exit 1
  fi
  install -d -o "${OPERATOR}" -g "${OPERATOR}" -m 755 "${RUNTIME}/app"
  runuser -u "${OPERATOR}" -- env HOME="${STATE}" PATH="${RUNTIME}/node/bin:/usr/bin:/bin" \
    npm install --prefix "${RUNTIME}/app" --omit=dev --no-audit --no-fund "openclaw@${OPENCLAW_VERSION}"
  chown -R root:root "${RUNTIME}/app"
  chmod -R a+rX "${RUNTIME}/app"
fi
operator_cli() {
  runuser -u "${OPERATOR}" -- env HOME="${STATE}" OPENCLAW_STATE_DIR="${STATE}/.openclaw" \
    OPENCLAW_NO_AUTO_UPDATE=1 PATH="${RUNTIME}/node/bin:/usr/local/bin:/usr/bin:/bin" \
    "${RUNTIME}/node/bin/node" "${RUNTIME}/app/node_modules/openclaw/openclaw.mjs" "$@"
}
operator_cli --version | grep -F "${OPENCLAW_VERSION}"

if [[ ! -f "${STATE}/.openclaw/openclaw.json" ]]; then
  operator_cli config set nodeHost.browserProxy.enabled false
  operator_cli config set nodeHost.autoUpdate.enabled false
  operator_cli approvals set --stdin <<'JSON'
{"version":1,"defaults":{"security":"allowlist","ask":"on-miss","askFallback":"deny","autoAllowSkills":false},"agents":{"main":{"allowlist":[{"pattern":"/usr/bin/id","argPattern":"^$"},{"pattern":"/usr/bin/docker","argPattern":"^ps$"}]}}}
JSON
fi

unit="/etc/systemd/system/${SERVICE}"
if [[ -f "${unit}" ]]; then
  cp -a "${unit}" "${STATE}/service.pre-install"
fi
cat > "${unit}" <<EOF
[Unit]
Description=OpenClaw dedicated host operator node
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=${OPERATOR}
Group=${OPERATOR}
SupplementaryGroups=${OFFICE_GROUP}
WorkingDirectory=${STATE}
Environment=HOME=${STATE}
Environment=OPENCLAW_STATE_DIR=${STATE}/.openclaw
Environment=OPENCLAW_NO_AUTO_UPDATE=1
Environment=DOCKER_HOST=unix://${ROOTLESS_SOCKET}
Environment=PATH=${RUNTIME}/node/bin:/usr/local/bin:/usr/bin:/bin
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=${STATE} ${OFFICE_DIR}
PrivateDevices=true
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
CapabilityBoundingSet=
ExecStart=${RUNTIME}/node/bin/node ${RUNTIME}/app/node_modules/openclaw/openclaw.mjs node run --host 127.0.0.1 --port 18789 --display-name host-operator --commands system.run.prepare,system.run,system.which,system.execApprovals.get,system.execApprovals.set
Restart=on-failure
RestartSec=10
KillMode=control-group
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
chmod 644 "${unit}"
systemd-analyze verify "${unit}"
# Persist only rootless socket access across daemon/socket recreation. Do not
# restart Docker: that would interrupt the Gateway and its running sandboxes.
acl_dropin="${GATEWAY_HOME}/.config/systemd/user/docker.service.d"
install -d -o "${GATEWAY_USER}" -g "${GATEWAY_GROUP}" -m 755 "${acl_dropin}"
cat > "${acl_dropin}/30-openclaw-operator-acl.conf" <<EOF
[Service]
ExecStartPost=/usr/bin/setfacl -m u:${OPERATOR}:--x /run/user/${GATEWAY_UID}
ExecStartPost=/usr/bin/setfacl -m u:${OPERATOR}:rw ${ROOTLESS_SOCKET}
EOF
chown "${GATEWAY_USER}:${GATEWAY_GROUP}" "${acl_dropin}/30-openclaw-operator-acl.conf"
chmod 644 "${acl_dropin}/30-openclaw-operator-acl.conf"
setfacl -m "u:${OPERATOR}:--x" "/run/user/${GATEWAY_UID}"
setfacl -m "u:${OPERATOR}:rw" "${ROOTLESS_SOCKET}"
runuser -u "${GATEWAY_USER}" -- env XDG_RUNTIME_DIR="/run/user/${GATEWAY_UID}" \
  systemctl --user daemon-reload
if runuser -u "${OPERATOR}" -- test -w /var/run/docker.sock; then
  echo "Refusing host operator startup: rootful Docker socket remains writable." >&2
  exit 1
fi
systemctl daemon-reload
if [[ ! -f "${STATE}/enrolled-device" ]]; then
  export GATEWAY_USER GATEWAY_UID OPERATOR STATE RUNTIME
  python3 - <<'PY'
import json
import os
from pathlib import Path
import signal
import subprocess
import time

state = Path(os.environ["STATE"])
runtime = os.environ["RUNTIME"]
uid = os.environ["GATEWAY_UID"]
gateway = ["runuser", "-u", os.environ["GATEWAY_USER"], "--", "env",
           f"XDG_RUNTIME_DIR=/run/user/{uid}", "docker", "-H",
           f"unix:///run/user/{uid}/docker.sock", "exec", "openclaw",
           "node", "dist/index.js", "gateway", "call"]

def call(method, params):
    result = subprocess.run(gateway + [method, "--params", json.dumps(params), "--json"],
                            capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError(f"Gateway RPC {method} failed; sensitive output suppressed")
    return json.loads(result.stdout)

setup = call("device.pair.setupCode", {"publicUrl": "ws://127.0.0.1:18789",
             "bootstrapProfile": "node", "includeQr": False})
operator = ["runuser", "-u", os.environ["OPERATOR"], "--", "env",
            f"HOME={state}", f"OPENCLAW_STATE_DIR={state}/.openclaw",
            "OPENCLAW_NO_AUTO_UPDATE=1", f"PATH={runtime}/node/bin:/usr/bin:/bin",
            f"{runtime}/node/bin/node", f"{runtime}/app/node_modules/openclaw/openclaw.mjs"]
commands = "system.run.prepare,system.run,system.which,system.execApprovals.get,system.execApprovals.set"
with (state / "enrollment.log").open("a") as log:
    proc = subprocess.Popen(operator + ["node", "run", "--pair", setup["setupCode"],
                            "--host", "127.0.0.1", "--port", "18789",
                            "--display-name", "host-operator", "--commands", commands],
                            stdout=log, stderr=log, start_new_session=True)
    try:
        deadline = time.monotonic() + 90
        completion = None
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                raise RuntimeError("Node enrollment exited; inspect restricted enrollment.log")
            status = call("device.pair.setupStatus", {"setupId": setup["setupId"]})
            completion = status.get("completion")
            if completion:
                break
            time.sleep(3)
        if not completion:
            raise RuntimeError("Pairing not confirmed; service has not been enabled")
        identity = subprocess.run(operator + ["node", "identity", "--json"],
                                  capture_output=True, text=True, check=True, timeout=30)
        local = json.loads(identity.stdout)
        if local.get("deviceId") != completion["deviceId"]:
            raise RuntimeError("Paired identity mismatch; refusing to enable service")
        (state / "enrolled-device").write_text(completion["deviceId"] + "\n")
        print("Pairing confirmed against local device identity; no setup code displayed.")
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
PY
fi
systemctl enable --now "${SERVICE}"
systemctl is-active "${SERVICE}"
export GATEWAY_USER GATEWAY_UID STATE
python3 - <<'PY'
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

device = (Path(os.environ["STATE"]) / "enrolled-device").read_text().strip()
uid = os.environ["GATEWAY_UID"]
base = ["runuser", "-u", os.environ["GATEWAY_USER"], "--", "env",
        f"XDG_RUNTIME_DIR=/run/user/{uid}", "docker", "-H",
        f"unix:///run/user/{uid}/docker.sock", "exec", "openclaw", "node", "dist/index.js"]
for attempt in range(20):
    result = subprocess.run(base + ["nodes", "status", "--json"],
                            capture_output=True, text=True, check=True, timeout=30)
    nodes = json.loads(result.stdout).get("nodes", [])
    if any(n.get("nodeId") == device and n.get("connected") and n.get("paired") for n in nodes):
        break
    time.sleep(3)
else:
    raise RuntimeError("Installed operator did not connect; no automatic rollback performed")

for command in (["/usr/bin/id"], ["/usr/bin/docker", "ps"]):
    params = {"nodeId": device, "command": "system.run",
              "params": {"command": command, "agentId": "main"},
              "idempotencyKey": str(uuid.uuid4())}
    result = subprocess.run(base + ["gateway", "call", "node.invoke", "--params",
                            json.dumps(params), "--json"], capture_output=True, text=True, timeout=30)
    if result.returncode or not json.loads(result.stdout).get("payload", {}).get("success"):
        raise RuntimeError("Paired read-only command failed; existing approval policy preserved")
print("Paired node connected; id and docker ps passed through the Gateway.")
PY
curl -fsS --max-time 10 http://127.0.0.1:18789/healthz >/dev/null
echo "Disable host access: sudo bash scripts/setup-openclaw-operator.sh disable"

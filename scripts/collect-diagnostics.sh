#!/usr/bin/env bash
# AI Lab — Diagnostic Collector
#
# Collects system info, service logs, configs, and network state
# into a zip archive for troubleshooting and support.
#
# Usage:
#   bash scripts/collect-diagnostics.sh
#
# Output:
#   ~/lab-diagnostics-YYYYMMDD-HHMM.zip
#
set -euo pipefail

TIMESTAMP="$(date +%Y%m%d-%H%M)"
DIAG_DIR="/tmp/lab-diagnostics-${TIMESTAMP}"
OUTPUT_FILE="${HOME}/lab-diagnostics-${TIMESTAMP}.tar.gz"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

mkdir -p "${DIAG_DIR}"

echo ""
echo "============================================="
echo "  AI Lab — Diagnostic Collector"
echo "============================================="
echo "  Timestamp: ${TIMESTAMP}"
echo "  Output:    ${OUTPUT_FILE}"
echo ""

# --- Helper ---
collect() {
  local name="$1"
  local cmd="$2"
  echo "  Collecting: ${name}"
  eval "${cmd}" > "${DIAG_DIR}/${name}.txt" 2>&1 || true
}

# --- System info ---
echo "[1/7] System info..."
collect "os-release"       "cat /etc/os-release"
collect "hostname"         "hostname -f"
collect "uptime"           "uptime"
collect "uname"            "uname -a"
collect "memory"           "free -h"
collect "disk"             "df -h"
collect "cpu"              "lscpu"
collect "ip-addresses"     "ip -4 addr show"
collect "timezone"         "timedatectl"

# --- Docker ---
echo "[2/7] Docker info..."
collect "docker-version"   "docker version"
collect "docker-info"      "docker info"
collect "docker-ps"        "docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
collect "docker-stats"     "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'"
collect "docker-networks"  "docker network ls && echo '---' && docker network inspect traefik-public 2>/dev/null"
collect "docker-volumes"   "docker volume ls"
collect "docker-disk"      "docker system df -v"
collect "docker-images"    "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}'"

# --- Docker Compose ---
echo "[3/7] Docker Compose..."
collect "compose-ps"       "cd ${PROJECT_DIR} && docker compose ps"
collect "compose-config"   "cd ${PROJECT_DIR} && docker compose config --no-interpolate 2>/dev/null || echo 'compose config not available'"

# --- Service logs (last 100 lines each) ---
echo "[4/7] Service logs..."
SERVICES="traefik flowise n8n langfuse langfuse-db ollama-compose qdrant-compose dify-api dify-worker dify-web dify-nginx dify-db dify-redis"
for svc in ${SERVICES}; do
  collect "log-${svc}" "docker logs --tail=100 ${svc} 2>&1"
done

# Native services
collect "log-ollama-systemd"  "sudo journalctl -u ollama --since '2 hours ago' --no-pager 2>/dev/null"
collect "log-docker-systemd"  "sudo journalctl -u docker --since '2 hours ago' --no-pager 2>/dev/null"
collect "log-ssh-systemd"     "sudo journalctl -u ssh --since '2 hours ago' --no-pager 2>/dev/null"
collect "log-fail2ban"        "sudo journalctl -u fail2ban --since '2 hours ago' --no-pager 2>/dev/null"
collect "log-cloud-init"      "sudo cat /var/log/cloud-init-output.log 2>/dev/null"
collect "cloud-init-status"   "cloud-init status --long 2>/dev/null"

# --- Network ---
echo "[5/7] Network diagnostics..."
collect "ports"            "sudo ss -tlnp"
collect "ufw-status"       "sudo ufw status verbose"
collect "ufw-rules"        "sudo ufw show added 2>/dev/null"
collect "iptables"         "sudo iptables -L -n --line-numbers 2>/dev/null"
collect "dns-resolve"      "for h in ai flow n8n trace dify; do echo \"--- \${h} ---\"; dig +short \${h}.$(grep '^DOMAIN=' ${PROJECT_DIR}/.env 2>/dev/null | cut -d= -f2 || echo 'example.com'); done"
collect "curl-traefik"     "curl -sf -o /dev/null -w 'HTTP %{http_code} (%{time_total}s)\n' http://localhost:80 2>/dev/null || echo 'traefik not reachable'"

# --- Configuration (sanitized — no secrets) ---
echo "[6/7] Configuration (sanitized)..."
# .env with secrets masked
if [ -f "${PROJECT_DIR}/.env" ]; then
  sed -E 's/(PASSWORD|SECRET|KEY|SALT|ENCRYPTION)=.*/\1=***REDACTED***/I' \
    "${PROJECT_DIR}/.env" > "${DIAG_DIR}/env-sanitized.txt"
fi
# docker-compose.yml
cp "${PROJECT_DIR}/docker-compose.yml" "${DIAG_DIR}/docker-compose.yml" 2>/dev/null || true
# Traefik acme.json summary (no private keys)
echo "  Collecting: traefik-acme"
docker exec traefik cat /certs/acme.json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for r, data in d.items():
        print('Resolver:', r)
        certs = data.get('Certificates', [])
        if not certs: print('  No certificates stored')
        for c in certs:
            dom = c.get('domain', {})
            print('  Main:', dom.get('main','?'), ' SANs:', dom.get('sans',[]))
except Exception as e:
    print('Parse error:', e)
" > "${DIAG_DIR}/traefik-acme.txt" 2>&1 || echo "Could not read acme.json" > "${DIAG_DIR}/traefik-acme.txt"

# Check actual TLS certificates on each subdomain
DOMAIN_VAL=$(grep '^DOMAIN=' "${PROJECT_DIR}/.env" 2>/dev/null | cut -d= -f2 || echo "")
if [ -n "${DOMAIN_VAL}" ]; then
  echo "  Collecting: tls-certificates"
  {
    for sub in dify flow n8n trace; do
      host="${sub}.${DOMAIN_VAL}"
      echo "--- ${host} ---"
      echo | openssl s_client -servername "${host}" -connect "${host}:443" 2>/dev/null \
        | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null \
        || echo "  No TLS certificate"
      echo
    done
  } > "${DIAG_DIR}/tls-certificates.txt" 2>&1
fi
# Docker API version override
collect "docker-api-override" "cat /etc/systemd/system/docker.service.d/min_api_version.conf 2>/dev/null || echo 'no override'"
# SSH config
collect "sshd-config" "grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port)' /etc/ssh/sshd_config 2>/dev/null"
# Fail2ban
collect "fail2ban-status" "sudo fail2ban-client status sshd 2>/dev/null"

# --- Validation ---
echo "[7/7] Running validation..."
collect "validate" "bash ${PROJECT_DIR}/scripts/validate.sh 2>&1"

# --- Create archive ---
echo ""
echo "  Creating archive..."
tar -czf "${OUTPUT_FILE}" -C /tmp "lab-diagnostics-${TIMESTAMP}/"
rm -rf "${DIAG_DIR}"

echo ""
echo "============================================="
echo "  Diagnostics collected successfully"
echo "============================================="
echo "  File: ${OUTPUT_FILE}"
echo "  Size: $(du -h "${OUTPUT_FILE}" | cut -f1)"
echo ""
echo "  Download via SCP:"
echo "    scp lab@<server-ip>:${OUTPUT_FILE} ."
echo ""
echo "  WARNING: Review the archive before sharing."
echo "  Secrets are redacted but verify manually."
echo "============================================="

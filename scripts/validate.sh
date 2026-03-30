#!/usr/bin/env bash
# AI Lab — Post-setup validation
#
# Checks that all components are installed and running.
# Run after setup.sh or cloud-init provisioning.
#
# Usage:
#   ~/ai-lab-server-setup/scripts/validate.sh
#   # or via alias:
#   lab-validate
#
set -euo pipefail

PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "${cmd}" &>/dev/null; then
    echo "  [OK]   ${name}"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] ${name}"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== AI Lab — Setup Validation ==="
echo ""

echo "System:"
check "Ubuntu 24.04"       "grep -q '24.04' /etc/os-release"
check "UFW active"         "sudo ufw status | grep -q 'Status: active'"
check "Fail2ban running"   "systemctl is-active fail2ban"
check "SSH hardened"       "grep -q 'PermitRootLogin no' /etc/ssh/sshd_config"

echo ""
echo "Services:"
check "Docker running"     "systemctl is-active docker"
check "Ollama running"     "systemctl is-active ollama"
check "Qdrant container"   "docker ps --format '{{.Names}}' | grep -q '^qdrant$'"

echo ""
echo "Tools:"
check "docker CLI"         "command -v docker"
check "ollama CLI"         "command -v ollama"
check "python3"            "command -v python3"
check "git"                "command -v git"

echo ""
echo "Network:"
check "Ollama API"         "curl -sf http://localhost:11434/api/tags > /dev/null"
check "Qdrant API"         "curl -sf http://localhost:6333/collections > /dev/null"

echo ""
echo "Environment:"
check "lab-venv exists"    "test -d ~/lab-venv"
check "pip in venv"        "test -x ~/lab-venv/bin/pip"

# --- Docker Compose platform stack (optional) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"

if [ -f "${PROJECT_DIR}/.env" ] && docker compose -f "${COMPOSE_FILE}" ps --quiet 2>/dev/null | grep -q .; then
  echo ""
  echo "Platform Stack (docker compose):"

  # Expected containers from docker-compose.yml
  CONTAINERS="traefik flowise n8n ollama-compose qdrant-compose langfuse langfuse-db dify-api dify-worker dify-web dify-nginx dify-db dify-redis"

  for container in ${CONTAINERS}; do
    check "${container}" "docker ps --format '{{.Names}}' | grep -q '^${container}$'"
  done

  echo ""
  echo "Platform APIs:"
  check "Traefik entrypoint"  "curl -sf -o /dev/null -w '%{http_code}' http://localhost:80 | grep -qE '(301|302|404)'"
  check "Flowise API"         "docker exec flowise wget -q --spider http://localhost:3000 2>/dev/null || docker exec flowise curl -sf http://localhost:3000 > /dev/null 2>&1 || docker exec traefik wget -q --spider http://flowise:3000 2>/dev/null"
  check "n8n API"             "docker exec n8n node -e \"require('http').get('http://localhost:5678/',r=>{process.exit(r.statusCode<400?0:1)}).on('error',()=>process.exit(1))\" 2>/dev/null"
  check "Langfuse API"        "docker exec langfuse node -e \"require('http').get('http://localhost:3000/',r=>{process.exit(r.statusCode<400?0:1)}).on('error',()=>process.exit(1))\" 2>/dev/null || docker exec traefik wget -q --spider http://langfuse:3000 2>/dev/null"
  check "Dify API"            "docker exec dify-nginx curl -sf http://localhost:80 > /dev/null 2>&1 || docker exec dify-nginx wget -q --spider http://localhost:80 2>/dev/null"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "${FAIL}" -gt 0 ]; then
  echo ""
  echo "Some checks failed. Review the output above."
  exit 1
else
  echo ""
  echo "All checks passed. Lab environment is ready."
fi

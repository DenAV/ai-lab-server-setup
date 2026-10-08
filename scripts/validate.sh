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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

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

qdrant_container_running() {
  docker ps --format '{{.Names}}' | grep -Eq '^(qdrant|qdrant-compose)$'
}

qdrant_api_reachable() {
  local qdrant_api_key=""
  local qdrant_ip=""
  local qdrant_header=()

  if [ -f "${PROJECT_DIR}/.env" ]; then
    qdrant_api_key="$(sed -n 's/^QDRANT_API_KEY=//p' "${PROJECT_DIR}/.env" | tail -n 1)"
  fi

  if [ -n "${qdrant_api_key}" ]; then
    qdrant_header=(-H "api-key: ${qdrant_api_key}")
  fi

  curl -sf "${qdrant_header[@]}" http://localhost:6333/collections > /dev/null 2>&1 && return 0

  if docker ps --format '{{.Names}}' | grep -q '^qdrant-compose$'; then
    qdrant_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' qdrant-compose)"
    if [ -n "${qdrant_ip}" ]; then
      curl -sf "${qdrant_header[@]}" "http://${qdrant_ip}:6333/collections" > /dev/null 2>&1
      return $?
    fi
  fi

  return 1
}

profile_enabled() {
  local expected="$1"
  local profiles="${COMPOSE_PROFILES:-}"

  if [ -z "${profiles}" ] && [ -f "${PROJECT_DIR}/.env" ]; then
    profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' "${PROJECT_DIR}/.env" | tail -n 1)"
  fi

  case ",${profiles// /}," in
    *,"${expected}",*) return 0 ;;
    *) return 1 ;;
  esac
}

openclaw_rootless_enabled() {
  [ "$(sed -n 's/^OPENCLAW_RUNTIME=//p' "${PROJECT_DIR}/.env" | tail -n 1)" = rootless ]
}

openclaw_rootless_running() {
  local rootless_user runtime_dir
  rootless_user="$(sed -n 's/^OPENCLAW_ROOTLESS_USER=//p' "${PROJECT_DIR}/.env" | tail -n 1)"
  runtime_dir="$(sed -n 's/^OPENCLAW_ROOTLESS_RUNTIME_DIR=//p' "${PROJECT_DIR}/.env" | tail -n 1)"
  [ -n "${rootless_user}" ] && [ -n "${runtime_dir}" ] || return 1
  sudo -n -u "${rootless_user}" env XDG_RUNTIME_DIR="${runtime_dir}" \
    docker -H "unix://${runtime_dir}/docker.sock" \
    inspect openclaw --format '{{.State.Health.Status}}' | grep -qx healthy
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
if profile_enabled "qdrant"; then
  check "Qdrant container" "qdrant_container_running"
fi

echo ""
echo "Tools:"
check "docker CLI"         "command -v docker"
check "python3"            "command -v python3"
check "git"                "command -v git"

echo ""
echo "Network:"
if profile_enabled "qdrant"; then
  check "Qdrant API"       "qdrant_api_reachable"
fi

echo ""
echo "Environment:"
check "lab-venv exists"    "test -d ~/lab-venv"
check "pip in venv"        "test -x ~/lab-venv/bin/pip"

COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"

if [ -f "${PROJECT_DIR}/.env" ] && docker compose -f "${COMPOSE_FILE}" ps --quiet 2>/dev/null | grep -q .; then
  echo ""
  echo "Platform Stack (docker compose):"

  CONTAINERS="traefik"
  profile_enabled "n8n" && CONTAINERS="${CONTAINERS} n8n"
  profile_enabled "openclaw" && CONTAINERS="${CONTAINERS} openclaw"
  profile_enabled "qdrant" && CONTAINERS="${CONTAINERS} qdrant-compose"
  profile_enabled "demo-db" && CONTAINERS="${CONTAINERS} demo-db"
  profile_enabled "langfuse" && CONTAINERS="${CONTAINERS} langfuse langfuse-db"
  profile_enabled "litellm" && CONTAINERS="${CONTAINERS} litellm litellm-db"
  profile_enabled "local-model" && CONTAINERS="${CONTAINERS} ollama-compose"
  profile_enabled "ffmpeg-worker" && CONTAINERS="${CONTAINERS} ffmpeg-worker"
  profile_enabled "yopass" && CONTAINERS="${CONTAINERS} yopass yopass-redis"
  if profile_enabled "dify"; then
    CONTAINERS="${CONTAINERS} dify-api dify-worker dify-beat dify-web dify-nginx"
    CONTAINERS="${CONTAINERS} dify-db dify-redis dify-sandbox dify-plugin-daemon"
  fi

  for container in ${CONTAINERS}; do
    check "${container}" "docker ps --format '{{.Names}}' | grep -q '^${container}$'"
  done
  if openclaw_rootless_enabled; then
    check "openclaw (rootless)" "openclaw_rootless_running"
  fi

  echo ""
  echo "Platform APIs:"
  check "Traefik entrypoint"  "curl -sf -o /dev/null -w '%{http_code}' http://localhost:80 | grep -qE '(301|302|404)'"
  if profile_enabled "n8n"; then
    check "n8n API"           "docker exec n8n node -e \"require('http').get('http://localhost:5678/',r=>{process.exit(r.statusCode<400?0:1)}).on('error',()=>process.exit(1))\" 2>/dev/null"
  fi
  if profile_enabled "langfuse"; then
    check "Langfuse API"      "docker exec langfuse node -e \"require('http').get('http://localhost:3000/',r=>{process.exit(r.statusCode<400?0:1)}).on('error',()=>process.exit(1))\" 2>/dev/null || docker exec traefik wget -q --spider http://langfuse:3000 2>/dev/null"
  fi
  if profile_enabled "dify"; then
    check "Dify API"          "docker exec dify-nginx curl -sf http://localhost:80 > /dev/null 2>&1 || docker exec dify-nginx wget -q --spider http://localhost:80 2>/dev/null"
  fi
  if profile_enabled "openclaw" || openclaw_rootless_enabled; then
    check "OpenClaw API"      "curl -sf http://127.0.0.1:18789/healthz > /dev/null"
  fi
  if profile_enabled "litellm"; then
    check "LiteLLM API"       "docker exec litellm python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:4000/health/readiness', timeout=5)\""
  fi
  if profile_enabled "local-model"; then
    check "Ollama API"        "docker exec ollama-compose ollama list"
  fi
  if profile_enabled "yopass"; then
    check "Yopass API"        "docker exec yopass /yopass-server --health-check"
  fi
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

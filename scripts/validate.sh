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

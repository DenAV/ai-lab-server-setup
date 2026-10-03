#!/usr/bin/env bash
# AI Lab Server Setup — Repository Tests
#
# Offline tests that validate scripts, configs, and repo structure.
# No server or Docker required — runs in CI or locally.
#
# Usage:
#   bash tests/test_repo.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

PASS=0
FAIL=0
SKIP=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

echo ""
echo "=== AI Lab — Repository Tests ==="
echo ""

# =========================================================================
# 1. Required files exist
# =========================================================================
echo "Structure:"
REQUIRED_FILES=(
  "README.md"
  "LICENSE"
  "CHANGELOG.md"
  "TROUBLESHOOTING.md"
  ".gitignore"
  ".editorconfig"
  ".yamllint.yml"
  ".env.example"
  "setup.sh"
  "docker-compose.yml"
  "docker-compose.workers.yml"
  "config/components.yml"
  "config/litellm-config.yml"
  "config/litellm-contracts.yml"
  "config/fail2ban.conf"
  "config/bash_aliases"
  "config/dify-nginx.conf"
  "scripts/generate-env.sh"
  "scripts/validate.sh"
  "scripts/collect-diagnostics.sh"
  "scripts/validate-component-catalog.py"
  "scripts/validate-compose-presets.py"
  "scripts/validate-doc-links.py"
  "scripts/validate-litellm-contracts.py"
  "scripts/validate-project-tracking.py"
  "examples/cloud-config.yml"
  "docs/README.md"
  "docs/project/ROADMAP.md"
  "docs/project/TODO.md"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "${PROJECT_DIR}/${f}" ]; then
    pass "${f} exists"
  else
    fail "${f} missing"
  fi
done

# =========================================================================
# 2. Bash syntax check (bash -n)
# =========================================================================
echo ""
echo "Bash syntax:"
SCRIPTS=(
  "setup.sh"
  "scripts/generate-env.sh"
  "scripts/validate.sh"
  "scripts/collect-diagnostics.sh"
)

for script in "${SCRIPTS[@]}"; do
  if bash -n "${PROJECT_DIR}/${script}" 2>/dev/null; then
    pass "${script}"
  else
    fail "${script} — syntax error"
  fi
done

# =========================================================================
# 3. ShellCheck (if available)
# =========================================================================
echo ""
echo "ShellCheck:"
if command -v shellcheck &>/dev/null; then
  for script in "${SCRIPTS[@]}"; do
    if shellcheck --severity=error "${PROJECT_DIR}/${script}" 2>/dev/null; then
      pass "${script}"
    else
      fail "${script} — shellcheck errors"
    fi
  done
else
  skip "shellcheck not installed"
fi

# =========================================================================
# 4. YAML syntax (python or yamllint)
# =========================================================================
echo ""
echo "YAML syntax:"
YAML_FILES=(
  "docker-compose.yml"
  "docker-compose.workers.yml"
  "compose.openclaw-cli.yml"
  "config/components.yml"
  "config/litellm-config.yml"
  "config/litellm-contracts.yml"
  "examples/cloud-config.yml"
)

if command -v yamllint &>/dev/null; then
  for yf in "${YAML_FILES[@]}"; do
    if yamllint -c "${PROJECT_DIR}/.yamllint.yml" "${PROJECT_DIR}/${yf}" 2>/dev/null; then
      pass "${yf}"
    else
      fail "${yf} — yamllint errors"
    fi
  done
elif command -v python3 &>/dev/null; then
  for yf in "${YAML_FILES[@]}"; do
    if python3 -c "import yaml; yaml.safe_load(open('${PROJECT_DIR}/${yf}'))" 2>/dev/null; then
      pass "${yf}"
    else
      fail "${yf} — YAML parse error"
    fi
  done
else
  skip "yamllint and python3 not available"
fi

# =========================================================================
# 5. Component catalog
# =========================================================================
echo ""
echo "Component catalog:"
if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
  if python3 "${PROJECT_DIR}/scripts/validate-component-catalog.py" &&
    python3 "${PROJECT_DIR}/scripts/validate-litellm-contracts.py"; then
    pass "component catalog and LiteLLM contracts valid"
  else
    fail "component catalog or LiteLLM contract validation failed"
  fi
else
  fail "python3 and PyYAML are required for component catalog validation"
fi

# =========================================================================
# 6. Docker Compose config validation
# =========================================================================
echo ""
echo "Docker Compose:"
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  validate_compose() {
    local name="$1"
    shift
    local args=()
    local file
    for file in "$@"; do
      args+=("-f" "${PROJECT_DIR}/${file}")
    done
    if docker compose "${args[@]}" \
      --env-file "${PROJECT_DIR}/.env.example" \
      config --quiet 2>/dev/null; then
      pass "${name} Compose model valid"
    else
      fail "${name} Compose model invalid"
    fi
  }

  validate_compose "base" "docker-compose.yml"
  validate_compose "workers overlay" "docker-compose.yml" "docker-compose.workers.yml"
  validate_compose "OpenClaw overlay" "docker-compose.yml" "compose.openclaw-cli.yml"
  validate_compose "combined overlays" \
    "docker-compose.yml" "docker-compose.workers.yml" "compose.openclaw-cli.yml"
  if python3 "${PROJECT_DIR}/scripts/validate-compose-presets.py"; then
    pass "Compose preset service closures valid"
  else
    fail "Compose preset service closures invalid"
  fi
else
  skip "docker compose not available"
fi

# =========================================================================
# 7. .env.example completeness
# =========================================================================
echo ""
echo "Environment:"

# Extract variables referenced in Compose files
COMPOSE_VARS=$(grep -hoP '\$\{(\w+)' \
  "${PROJECT_DIR}/docker-compose.yml" \
  "${PROJECT_DIR}/docker-compose.workers.yml" \
  "${PROJECT_DIR}/compose.openclaw-cli.yml" | sed 's/\${//' | sort -u)
ENV_VARS=$(grep -oP '^\w+=' "${PROJECT_DIR}/.env.example" | sed 's/=//' | sort -u)

MISSING_VARS=0
for var in ${COMPOSE_VARS}; do
  # Skip variables with defaults (:-) in compose
  if grep -qP "\\\$\{${var}:-" \
    "${PROJECT_DIR}/docker-compose.yml" \
    "${PROJECT_DIR}/docker-compose.workers.yml" \
    "${PROJECT_DIR}/compose.openclaw-cli.yml"; then
    continue
  fi
  if ! echo "${ENV_VARS}" | grep -q "^${var}$"; then
    fail ".env.example missing ${var}"
    MISSING_VARS=$((MISSING_VARS + 1))
  fi
done
if [ "${MISSING_VARS}" -eq 0 ]; then
  pass ".env.example has all required variables"
fi

# =========================================================================
# 8. No secrets in committed files
# =========================================================================
echo ""
echo "Security:"

# Check for common secret patterns in tracked files
SECRET_PATTERNS="(password|secret|token|api.key)\s*[:=]\s*['\"]?[a-zA-Z0-9+/]{16,}"
if git -C "${PROJECT_DIR}" ls-files 2>/dev/null | while read -r f; do
    grep -iEq "${SECRET_PATTERNS}" "${PROJECT_DIR}/${f}" 2>/dev/null && echo "${f}" && break
  done | grep -q .; then
  fail "Possible hardcoded secret found in tracked files"
else
  pass "No hardcoded secrets in tracked files"
fi

# .env should be gitignored
if grep -q '\.env$\|/\.env' "${PROJECT_DIR}/.gitignore" 2>/dev/null; then
  pass ".env is gitignored"
else
  fail ".env not in .gitignore"
fi

# .secrets should be gitignored
if grep -q '\.secrets' "${PROJECT_DIR}/.gitignore" 2>/dev/null; then
  pass ".secrets is gitignored"
else
  fail ".secrets not in .gitignore"
fi

# =========================================================================
# 9. Documentation links
# =========================================================================
echo ""
echo "Documentation:"

# Check that all setup guides referenced in README exist
GUIDE_LINKS=$(grep -oP 'docs/platforms/setup-[[:alnum:]_-]+\.md' "${PROJECT_DIR}/README.md" | sort -u)
for guide in ${GUIDE_LINKS}; do
  if [ -f "${PROJECT_DIR}/${guide}" ]; then
    pass "${guide} exists"
  else
    fail "${guide} referenced in README but missing"
  fi
done

# Check TROUBLESHOOTING.md is referenced
if grep -q "TROUBLESHOOTING.md" "${PROJECT_DIR}/README.md"; then
  pass "TROUBLESHOOTING.md linked in README"
else
  fail "TROUBLESHOOTING.md not linked in README"
fi

if python3 "${PROJECT_DIR}/scripts/validate-doc-links.py"; then
  pass "Markdown relative links valid"
else
  fail "Markdown relative links invalid"
fi

if python3 "${PROJECT_DIR}/scripts/validate-project-tracking.py"; then
  pass "Roadmap and TODO tracking consistent"
else
  fail "Roadmap and TODO tracking inconsistent"
fi

# =========================================================================
# Results
# =========================================================================
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ==="

if [ "${FAIL}" -gt 0 ]; then
  echo ""
  echo "Some tests failed. Review the output above."
  exit 1
else
  echo ""
  echo "All tests passed."
fi

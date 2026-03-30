#!/usr/bin/env bash
# AI Lab Server Setup — Universal provisioning for Ubuntu 24.04
#
# Sets up a complete AI lab environment on any fresh Ubuntu 24.04 server.
# Works with any cloud provider (Hetzner, AWS, Azure, GCP) or bare metal.
#
# Usage:
#   Option A — clone and run:
#     git clone https://github.com/DenAV/ai-lab-server-setup.git /opt/ai-lab-server-setup
#     sudo /opt/ai-lab-server-setup/setup.sh
#
#   Option B — pipe over SSH:
#     ssh root@<server-ip> 'bash -s' < setup.sh
#     (config files will be auto-cloned from GitHub)
#
#   Option C — via cloud-init:
#     See examples/cloud-config.yml
#
# After setup, login as 'lab' user:
#   ssh lab@<server-ip>
#
set -euo pipefail

# === Configuration (override via environment) ===
LAB_USER="${LAB_USER:-lab}"
TIMEZONE="${TIMEZONE:-Europe/Berlin}"
QDRANT_VERSION="${QDRANT_VERSION:-v1.12.1}"
OLLAMA_MODELS="${OLLAMA_MODELS:-llama3.2 nomic-embed-text}"
REPO_URL="https://github.com/DenAV/ai-lab-server-setup.git"

# === Detect repo directory ===
# If running from within the cloned repo, use local config files.
# If running standalone (piped via SSH), clone the repo first.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd || echo "")"
if [ -n "${SCRIPT_DIR}" ] && [ -f "${SCRIPT_DIR}/config/fail2ban.conf" ]; then
  REPO_DIR="${SCRIPT_DIR}"
else
  REPO_DIR="/opt/ai-lab-server-setup"
  if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "[*] Cloning config repository..."
    apt-get update -qq && apt-get install -y -qq git
    git clone "${REPO_URL}" "${REPO_DIR}"
  fi
fi

# === Preflight checks ===
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root" >&2
  exit 1
fi

if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  echo "WARNING: This script is designed for Ubuntu 24.04. Proceed with caution."
fi

echo ""
echo "============================================="
echo "  AI Lab Server Setup"
echo "============================================="
echo "  User:     ${LAB_USER}"
echo "  Timezone: ${TIMEZONE}"
echo "  Qdrant:   ${QDRANT_VERSION}"
echo "  Config:   ${REPO_DIR}"
echo "============================================="
echo ""

# --- 1. System update ---
echo "[1/9] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget git unzip htop \
  ufw fail2ban \
  python3.12 python3.12-venv python3-pip \
  apt-transport-https ca-certificates gnupg lsb-release

# --- 2. Timezone ---
echo "[2/9] Setting timezone to ${TIMEZONE}..."
timedatectl set-timezone "${TIMEZONE}"

# --- 3. Create lab user ---
echo "[3/9] Creating user '${LAB_USER}'..."
if ! id "${LAB_USER}" &>/dev/null; then
  adduser --disabled-password --gecos "" "${LAB_USER}"
  usermod -aG sudo "${LAB_USER}"
  echo "${LAB_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${LAB_USER}"
  chmod 440 "/etc/sudoers.d/${LAB_USER}"

  # Copy SSH keys from root (cloud providers inject keys into root)
  if [ -f /root/.ssh/authorized_keys ]; then
    mkdir -p "/home/${LAB_USER}/.ssh"
    cp /root/.ssh/authorized_keys "/home/${LAB_USER}/.ssh/"
    chown -R "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}/.ssh"
    chmod 700 "/home/${LAB_USER}/.ssh"
    chmod 600 "/home/${LAB_USER}/.ssh/authorized_keys"
  fi
  echo "  User '${LAB_USER}' created"
else
  echo "  User '${LAB_USER}' already exists"
fi

# Fix home directory ownership (cloud-init write_files may create /home/lab
# as root before the users module runs)
chown -R "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}"

# --- 4. SSH hardening ---
echo "[4/9] Hardening SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CONFIG}"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONFIG}"
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "${SSHD_CONFIG}"
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' "${SSHD_CONFIG}"
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "${SSHD_CONFIG}"
sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' "${SSHD_CONFIG}"
sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' "${SSHD_CONFIG}"
# Ubuntu 24.04 uses ssh.service, not sshd.service
systemctl restart ssh
echo "  SSH hardened (root login disabled, password auth disabled)"

# --- 5. Firewall ---
echo "[5/9] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
echo "y" | ufw enable
echo "  Firewall enabled (SSH, HTTP, HTTPS)"

# --- 6. Fail2ban ---
echo "[6/9] Configuring Fail2ban..."
cp "${REPO_DIR}/config/fail2ban.conf" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban
echo "  Fail2ban active"

# --- 7. Docker ---
echo "[7/9] Installing Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  echo "  Docker installed"
else
  echo "  Docker already installed"
fi
# Ensure lab user is in docker group
usermod -aG docker "${LAB_USER}"

# Fix Docker 29+ / Traefik API version compatibility
if ! grep -q "DOCKER_MIN_API_VERSION" /etc/systemd/system/docker.service.d/min_api_version.conf 2>/dev/null; then
  mkdir -p /etc/systemd/system/docker.service.d
  printf '[Service]\nEnvironment="DOCKER_MIN_API_VERSION=1.24"\n' \
    > /etc/systemd/system/docker.service.d/min_api_version.conf
  systemctl daemon-reload
  systemctl restart docker
  echo "  Docker API version fix applied"
fi

# --- 8. Ollama ---
echo "[8/9] Installing Ollama..."
if ! command -v ollama &>/dev/null; then
  curl -fsSL https://ollama.com/install.sh | sh
  systemctl enable ollama
  echo "  Ollama installed"
else
  echo "  Ollama already installed"
fi

# Pull models in background
if [ -n "${OLLAMA_MODELS}" ]; then
  echo "  Pulling models in background: ${OLLAMA_MODELS}"
  PULL_CMD=""
  for model in ${OLLAMA_MODELS}; do
    PULL_CMD="${PULL_CMD} && ollama pull ${model}"
  done
  PULL_CMD="${PULL_CMD# && }"
  su - "${LAB_USER}" -c "nohup bash -c 'sleep 30 && ${PULL_CMD}' > /tmp/ollama-pull.log 2>&1 &"
fi

# --- 9. Qdrant + Python + shell config ---
echo "[9/9] Setting up lab environment..."

# Qdrant
if ! docker ps -a --format '{{.Names}}' | grep -q '^qdrant$'; then
  docker run -d --name qdrant --restart unless-stopped \
    -p 6333:6333 -v qdrant_data:/qdrant/storage \
    "qdrant/qdrant:${QDRANT_VERSION}"
  echo "  Qdrant ${QDRANT_VERSION} started"
else
  docker start qdrant 2>/dev/null || true
  echo "  Qdrant already exists"
fi

# Python venv
su - "${LAB_USER}" -c "python3 -m venv ~/lab-venv"
su - "${LAB_USER}" -c "~/lab-venv/bin/pip install --upgrade pip -q"
echo "  Python venv created at ~/lab-venv"

# Shell aliases
cp "${REPO_DIR}/config/bash_aliases" "/home/${LAB_USER}/.bash_aliases"
chown "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}/.bash_aliases"

# Ensure repo is available in lab user home
if [ ! -d "/home/${LAB_USER}/ai-lab-server-setup" ]; then
  if [ "${REPO_DIR}" != "/home/${LAB_USER}/ai-lab-server-setup" ]; then
    su - "${LAB_USER}" -c "git clone ${REPO_URL} ~/ai-lab-server-setup" || true
  fi
fi
if [ -d "/home/${LAB_USER}/ai-lab-server-setup" ]; then
  chown -R "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}/ai-lab-server-setup"
fi

# Done marker
echo "Setup completed at $(date)" > "/home/${LAB_USER}/.setup-done"
chown "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}/.setup-done"

echo ""
echo "============================================="
echo "  AI Lab setup complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  1. Login as '${LAB_USER}':  ssh ${LAB_USER}@<server-ip>"
echo "  2. Activate Python venv:    source ~/lab-venv/bin/activate"
echo "  3. Check services:          ~/ai-lab-server-setup/scripts/validate.sh"
echo ""
echo "Optional — deploy AI platform stack:"
echo "  cd ~/ai-lab-server-setup"
echo "  cp .env.example .env && nano .env"
echo "  docker compose up -d"
echo ""
echo "Ollama models are downloading in background."
echo "Check progress:  tail -f /tmp/ollama-pull.log"
echo ""
echo "WARNING: Root SSH access is now disabled."
echo "Make sure you can login as '${LAB_USER}' before closing this session!"

#!/usr/bin/env bash
# ==============================================================================
# setup-tailscale-ssh.sh
# Multi-Platform Tailscale SSH Setup & Management for Zero-Trust Remote Terminal.
# Supports Arch/CachyOS Linux, WSL2 (Ubuntu/Debian), and macOS.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECRET_FILE="${REPO_ROOT}/secrets/tailscale.enc.yaml"
ENV_FILE="${HOME}/.local/share/local-services/.env"

ACTION="up"
for arg in "$@"; do
  case "$arg" in
    --status)
      ACTION="status"
      ;;
    --down)
      ACTION="down"
      ;;
    --up)
      ACTION="up"
      ;;
    -h|--help)
      echo "Usage: $0 [--up | --status | --down]"
      echo ""
      echo "Commands:"
      echo "  --up       Install, configure, and enable Tailscale SSH on this host (default)"
      echo "  --status   Inspect host Tailscale daemon status, IP, and SSH readiness"
      echo "  --down     Disable Tailscale SSH on this host"
      exit 0
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Helper: Check and require sudo if not running as root
# ------------------------------------------------------------------------------
run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# ------------------------------------------------------------------------------
# Helper: Detect Platform Environment
# ------------------------------------------------------------------------------
detect_platform() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "darwin"
  elif grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    echo "wsl"
  elif [ -f /etc/os-release ] && grep -qiE "cachyos|arch" /etc/os-release; then
    echo "arch"
  elif [ -f /etc/os-release ] && grep -qiE "ubuntu|debian" /etc/os-release; then
    echo "debian"
  else
    echo "linux"
  fi
}

PLATFORM="$(detect_platform)"

# ------------------------------------------------------------------------------
# Action: Status
# ------------------------------------------------------------------------------
if [ "$ACTION" = "status" ]; then
  echo "======================================================================"
  echo "🔍 Host Tailscale SSH Status (${PLATFORM})"
  echo "======================================================================"
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "⚠️ Tailscale CLI is not installed on this host."
    echo "👉 Run '$0 --up' or 'jl up-ssh' to set up Tailscale SSH."
    exit 1
  fi

  if ! tailscale status >/dev/null 2>&1; then
    echo "⚠️ Tailscale daemon is not running or not logged in."
    echo "👉 Run '$0 --up' or 'jl up-ssh' to authenticate and start Tailscale SSH."
    exit 1
  fi

  STATUS_JSON="$(tailscale status --json 2>/dev/null || true)"
  SELF_DNS="$(echo "$STATUS_JSON" | jq -r '.Self.DNSName // empty' 2>/dev/null || true)"
  SELF_DNS="${SELF_DNS%.}"
  SELF_IP="$(tailscale ip -4 2>/dev/null || true)"
  SELF_HOSTNAME="$(echo "$STATUS_JSON" | jq -r '.Self.HostName // empty' 2>/dev/null || true)"
  SSH_ENABLED="$(echo "$STATUS_JSON" | jq -r '.Self.Capabilities[]? | select(. == "https://tailscale.com/cap/ssh")' 2>/dev/null || true)"

  echo "  Host Name:       ${SELF_HOSTNAME:-$(hostname)}"
  echo "  MagicDNS Name:   ${SELF_DNS:-unknown}"
  echo "  Tailscale IPv4:  ${SELF_IP:-unknown}"
  if [ -n "$SSH_ENABLED" ]; then
    echo "  Tailscale SSH:   ✅ ACTIVE & LISTENING"
  else
    echo "  Tailscale SSH:   ⚠️ NOT ACTIVE (Run 'tailscale set --ssh=true')"
  fi
  echo ""
  echo "👉 Connect from any device on your Tailnet:"
  echo "   ssh ${USER}@${SELF_HOSTNAME:-$(hostname)}"
  if [ -n "$SELF_DNS" ]; then
    echo "   ssh ${USER}@${SELF_DNS}"
  fi
  echo "======================================================================"
  exit 0
fi

# ------------------------------------------------------------------------------
# Action: Down (Disable SSH)
# ------------------------------------------------------------------------------
if [ "$ACTION" = "down" ]; then
  echo "==> Disabling Tailscale SSH on host..."
  if command -v tailscale >/dev/null 2>&1; then
    run_sudo tailscale set --ssh=false
    echo "✓ Tailscale SSH disabled on this host."
  else
    echo "Tailscale is not installed."
  fi
  exit 0
fi

# ------------------------------------------------------------------------------
# Action: Up (Install & Configure Tailscale SSH)
# ------------------------------------------------------------------------------
echo "======================================================================"
echo "🚀 Setting up Tailscale SSH for Zero-Trust Remote Terminal Access"
echo "   Detected Platform: ${PLATFORM}"
echo "======================================================================"

# 1. Install Tailscale package if missing
if ! command -v tailscale >/dev/null 2>&1 || ! command -v tailscaled >/dev/null 2>&1; then
  echo "==> Tailscale not found on host. Installing for platform: ${PLATFORM}..."
  case "$PLATFORM" in
    arch)
      echo "==> Installing tailscale via pacman..."
      run_sudo pacman -Sy --needed --noconfirm tailscale
      ;;
    debian|wsl)
      echo "==> Installing tailscale via official Tailscale repository..."
      curl -fsSL https://tailscale.com/install.sh | sh
      ;;
    darwin)
      if command -v brew >/dev/null 2>&1; then
        echo "==> Installing tailscale via Homebrew..."
        brew install tailscale
      else
        echo "❌ Homebrew not found. Please install Tailscale from https://tailscale.com/download/mac" >&2
        exit 1
      fi
      ;;
    *)
      echo "❌ Unsupported platform for automatic install. Please install tailscale manually." >&2
      exit 1
      ;;
  esac
fi

# 2. Enable and start tailscaled daemon
echo "==> Ensuring tailscaled daemon is active..."
if [ "$PLATFORM" = "darwin" ]; then
  if ! pgrep -q tailscaled 2>/dev/null; then
    if command -v brew >/dev/null 2>&1; then
      brew services start tailscale 2>/dev/null || run_sudo tailscaled install-system-daemon 2>/dev/null || true
    fi
  fi
elif command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
  echo "==> Enabling and starting tailscaled.service via systemd..."
  run_sudo systemctl enable --now tailscaled.service
else
  # Fallback for WSL without systemd or container hosts
  if ! pgrep -q tailscaled 2>/dev/null; then
    echo "==> Starting tailscaled in background (no active systemd detected)..."
    run_sudo tailscaled --state=/var/lib/tailscale/tailscaled.state >/dev/null 2>&1 &
    sleep 2
  fi
fi

# 3. Determine target machine hostname
TARGET_MACHINE=""
if [ -f "$ENV_FILE" ]; then
  TARGET_MACHINE="$(grep '^TS_MACHINE_ID=' "$ENV_FILE" | cut -d'=' -f2 | tr -d ' "')"
fi
if [ -z "$TARGET_MACHINE" ]; then
  HOST_STRING="$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo "")"
  if [[ "$HOST_STRING" =~ [Ee][Nn][Vv][Yy] ]]; then
    TARGET_MACHINE="envy"
  elif [[ "$HOST_STRING" =~ [Aa][Ss][Uu][Ss] ]]; then
    TARGET_MACHINE="asus"
  elif [[ "$HOST_STRING" =~ [Aa][Rr][Cc][Hh] ]]; then
    TARGET_MACHINE="arch"
  else
    TARGET_MACHINE="$(hostname -s 2>/dev/null | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  fi
  TARGET_MACHINE="${TARGET_MACHINE:-laptop}"
fi

# Adjust hostname suffix for WSL to prevent collision with dual-boot bare-metal host
if [ "$PLATFORM" = "wsl" ]; then
  TARGET_HOSTNAME="${TARGET_MACHINE}-wsl"
elif [ "$PLATFORM" = "darwin" ]; then
  TARGET_HOSTNAME="${TARGET_MACHINE}-mac"
else
  TARGET_HOSTNAME="${TARGET_MACHINE}"
fi

# 4. Decrypt TS_AUTHKEY ephemerally via SOPS if not already authenticated
IS_ALREADY_UP=false
if tailscale status >/dev/null 2>&1; then
  CURRENT_STATE="$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty' 2>/dev/null || true)"
  if [ "$CURRENT_STATE" = "Running" ]; then
    IS_ALREADY_UP=true
  fi
fi

if [ "$IS_ALREADY_UP" = true ]; then
  echo "==> Tailscale is already logged in and running. Enabling Tailscale SSH..."
  run_sudo tailscale set --ssh=true --hostname="${TARGET_HOSTNAME}"
else
  echo "==> Tailscale is not logged in. Ephemerally decrypting auth key from SOPS..."
  TS_AUTHKEY=""
  if [ -f "$SECRET_FILE" ]; then
    if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
      if [ -f "${HOME}/.config/sops/age/keys.txt" ]; then
        export SOPS_AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
      elif [ -f "${HOME}/.ssh/id_ed25519" ]; then
        export SOPS_AGE_KEY_FILE="${HOME}/.ssh/id_ed25519"
      fi
    fi
    TS_AUTHKEY="$(sops --decrypt --extract '["tailscale"]["auth_key"]' "$SECRET_FILE" 2>/dev/null || true)"
  fi

  if [ -n "$TS_AUTHKEY" ]; then
    echo "==> Authenticating host Tailscale daemon with in-memory auth key (${TS_AUTHKEY:0:15}...)..."
    run_sudo tailscale up \
      --authkey="${TS_AUTHKEY}" \
      --hostname="${TARGET_HOSTNAME}" \
      --ssh \
      --accept-routes
    unset TS_AUTHKEY
  else
    echo "ℹ️  No encrypted auth key found or SOPS decryption unavailable. Initiating interactive Tailscale login..."
    run_sudo tailscale up \
      --hostname="${TARGET_HOSTNAME}" \
      --ssh \
      --accept-routes
  fi
fi

# 5. Verify & Print Connection Information
echo ""
echo "======================================================================"
echo "🎉 Tailscale SSH Successfully Configured!"
echo "======================================================================"
SELF_IP="$(tailscale ip -4 2>/dev/null || echo "Tailscale IP pending...")"
STATUS_JSON="$(tailscale status --json 2>/dev/null || true)"
SELF_DNS="$(echo "$STATUS_JSON" | jq -r '.Self.DNSName // empty' 2>/dev/null || true)"
SELF_DNS="${SELF_DNS%.}"

echo "  Device Hostname:  ${TARGET_HOSTNAME}"
echo "  Tailscale IPv4:   ${SELF_IP}"
[ -n "$SELF_DNS" ] && echo "  MagicDNS FQDN:    ${SELF_DNS}"
echo ""
echo "📱 How to connect from any device on your Tailnet (Phone, Laptop, iPad):"
echo "   ssh ${USER}@${TARGET_HOSTNAME}"
[ -n "$SELF_DNS" ] && echo "   ssh ${USER}@${SELF_DNS}"
echo ""
echo "🔒 Tailnet Access Control List (ACL) Requirement:"
echo "   Tailscale requires SSH permission in your Tailnet ACL policy."
echo "   Open https://login.tailscale.com/admin/acls and ensure an 'ssh' block exists:"
echo ""
echo '   "ssh": ['
echo '     {'
echo '       "action": "accept",'
echo '       "src": ["autogroup:member"],'
echo '       "dst": ["tag:local-services", "autogroup:self"],'
echo '       "users": ["autogroup:nonroot", "root"]'
echo '     }'
echo '   ]'
echo "======================================================================"

#!/usr/bin/env bash
# ==============================================================================
# sync-tailscale-key.sh
# Decrypts secrets/tailscale.enc.yaml using local host SSH or age key,
# and updates TS_AUTHKEY in ~/.local/share/local-services/.env.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECRET_FILE="${REPO_ROOT}/secrets/tailscale.enc.yaml"
LOCAL_SERVICES_DIR="${REPO_ROOT}/local-services"
ENV_FILE="${LOCAL_SERVICES_DIR}/.env"
XDG_ENV_FILE="${HOME}/.local/share/local-services/.env"

# 1. Ensure sops is available
if ! command -v sops >/dev/null 2>&1; then
  if [ -x "${HOME}/.nix-profile/bin/sops" ]; then
    export PATH="${HOME}/.nix-profile/bin:${PATH}"
  else
    echo "⚠️ sops is not installed or not in PATH. Please install SOPS." >&2
    exit 1
  fi
fi

# 2. Check if secrets/tailscale.enc.yaml exists
if [ ! -f "${SECRET_FILE}" ]; then
  echo "⚠️ Encrypted secret file not found: ${SECRET_FILE}" >&2
  exit 1
fi

# 3. Resolve decryption key (master age key or host SSH ed25519 key)
if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
  if [ -f "${HOME}/.config/sops/age/keys.txt" ]; then
    export SOPS_AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
  elif [ -f "${HOME}/.ssh/id_ed25519" ]; then
    export SOPS_AGE_KEY_FILE="${HOME}/.ssh/id_ed25519"
  fi
fi

# 4. Decrypt Tailscale secret payload
DECRYPTED_PAYLOAD="$(sops --decrypt "${SECRET_FILE}" 2>/dev/null || true)"

if [ -z "${DECRYPTED_PAYLOAD}" ] && [ -f "${HOME}/.ssh/id_ed25519" ]; then
  export SOPS_AGE_KEY_FILE="${HOME}/.ssh/id_ed25519"
  DECRYPTED_PAYLOAD="$(sops --decrypt "${SECRET_FILE}" 2>/dev/null || true)"
fi

if [ -z "${DECRYPTED_PAYLOAD}" ]; then
  echo "❌ Failed to decrypt ${SECRET_FILE}." >&2
  echo "👉 Ensure your local SSH key (~/.ssh/id_ed25519.pub) or age key is registered in .sops.yaml." >&2
  exit 1
fi

AUTH_KEY="$(echo "${DECRYPTED_PAYLOAD}" | awk -F: '/auth_key:/ {gsub(/[ "]/, "", $2); print $2}' | head -n 1)"

if [ -z "${AUTH_KEY}" ]; then
  echo "ℹ️  ${SECRET_FILE} decrypted successfully, but 'tailscale.auth_key' is currently empty."
  echo "👉 Run 'jl rotate-auth-key' (or edit via 'sops ${SECRET_FILE}') to populate it."
  exit 0
fi

# 5. Sanitize local-services/.env (strip TS_AUTHKEY to ensure zero plaintext on disk)
mkdir -p "${LOCAL_SERVICES_DIR}"
if [ ! -f "${ENV_FILE}" ]; then
  if [ -f "${XDG_ENV_FILE}" ]; then
    cp "${XDG_ENV_FILE}" "${ENV_FILE}"
  else
    HOST_STRING="$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo "")"
    if [[ "$HOST_STRING" =~ [Ee][Nn][Vv][Yy] ]]; then
      MACHINE_ID="envy"
    elif [[ "$HOST_STRING" =~ [Aa][Ss][Uu][Ss] ]]; then
      MACHINE_ID="asus"
    elif [[ "$HOST_STRING" =~ [Aa][Rr][Cc][Hh] ]]; then
      MACHINE_ID="arch"
    else
      MACHINE_ID="$(hostname -s 2>/dev/null | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
      MACHINE_ID="${MACHINE_ID:-laptop}"
    fi
    cat << EOF > "${ENV_FILE}"
# Local Services Environment Configuration (Zero Secrets)
TS_MACHINE_ID=${MACHINE_ID}
EOF
  fi
fi

# Strip TS_AUTHKEY if previously written to disk
if grep -q "^TS_AUTHKEY=" "${ENV_FILE}"; then
  sed -i "/^TS_AUTHKEY=/d" "${ENV_FILE}"
fi
chmod 600 "${ENV_FILE}"
echo "✓ Successfully verified SOPS decryption with host SSH key (${AUTH_KEY:0:15}...)"
echo "✓ Sanitized ${ENV_FILE} (zero plaintext tokens stored on disk; auth key is injected in-memory during 'jl up-remote')"

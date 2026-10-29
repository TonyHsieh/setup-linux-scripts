#!/usr/bin/env bash
# ==============================================================================
# register-host-key.sh
# Purpose: Authorize current host's SSH ed25519 key for SOPS multi-recipient encryption
# Allows new laptops/servers to decrypt secrets locally without plaintext keys.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOPS_CONFIG="${REPO_ROOT}/.sops.yaml"
SECRET_FILE="${REPO_ROOT}/secrets/tailscale.enc.yaml"
SSH_PUBKEY_FILE="${HOME}/.ssh/id_ed25519.pub"
SSH_PRIVKEY_FILE="${HOME}/.ssh/id_ed25519"

DO_COMMIT=false
for arg in "$@"; do
  case "$arg" in
    --commit)
      DO_COMMIT=true
      ;;
  esac
done

echo "==> 🔑 Checking Host SSH Key for SOPS Authorization..."

# 1. Ensure SSH ed25519 keypair exists
if [ ! -f "$SSH_PUBKEY_FILE" ]; then
  echo "==> Generating new ed25519 SSH keypair at ${SSH_PRIVKEY_FILE}..."
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  ssh-keygen -t ed25519 -N "" -f "${SSH_PRIVKEY_FILE}" -C "tailscale-$(hostname -s 2>/dev/null || echo 'host')"
fi

PUBKEY="$(awk '{print $1" "$2}' "${SSH_PUBKEY_FILE}" | tr -d '\r\n')"
KEY_COMMENT="$(awk '{print $3}' "${SSH_PUBKEY_FILE}" 2>/dev/null || echo "")"

if [ -z "$PUBKEY" ]; then
  echo "❌ Error: Could not read public key from ${SSH_PUBKEY_FILE}" >&2
  exit 1
fi

echo "    Host Public Key: ${PUBKEY:0:30}... (${KEY_COMMENT:-no-comment})"

# 2. Check if key is already in .sops.yaml
if grep -qF "$PUBKEY" "${SOPS_CONFIG}"; then
  echo "✅ Host SSH key is already registered in ${SOPS_CONFIG}."
else
  echo "==> Registering host SSH key in ${SOPS_CONFIG}..."

  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import sys
path = sys.argv[1]
key = sys.argv[2]
with open(path, 'r') as f:
    lines = [l.rstrip() for l in f.readlines()]
while lines and not lines[-1].strip():
    lines.pop()
if lines and not lines[-1].endswith(','):
    lines[-1] = lines[-1] + ','
lines.append(f'      {key}')
with open(path, 'w') as f:
    f.write('\n'.join(lines) + '\n')
" "${SOPS_CONFIG}" "${PUBKEY}"
  else
    # Pure POSIX shell fallback without while-loop traps
    TMP_CONFIG="$(mktemp /tmp/sops-XXXXXX.yaml)"
    awk 'NF {last=NR} {lines[NR]=$0} END {for(i=1;i<=last;i++) {if(i==last && lines[i] !~ /,[ \t]*$/) lines[i]=lines[i] ","; print lines[i]}}' "${SOPS_CONFIG}" > "${TMP_CONFIG}"
    echo "      ${PUBKEY}" >> "${TMP_CONFIG}"
    mv "${TMP_CONFIG}" "${SOPS_CONFIG}"
  fi
  echo "✅ Added host SSH key to ${SOPS_CONFIG}"
fi

# 3. Test if machine can decrypt existing secrets to perform updatekeys
SOPS_KEY_ENV=""
if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
  if [ -f "${HOME}/.config/sops/age/keys.txt" ]; then
    SOPS_KEY_ENV="${HOME}/.config/sops/age/keys.txt"
  elif [ -f "${SSH_PRIVKEY_FILE}" ]; then
    SOPS_KEY_ENV="${SSH_PRIVKEY_FILE}"
  fi
else
  SOPS_KEY_ENV="${SOPS_AGE_KEY_FILE}"
fi

CAN_DECRYPT=false
if [ -n "$SOPS_KEY_ENV" ] && [ -f "$SECRET_FILE" ]; then
  if SOPS_AGE_KEY_FILE="$SOPS_KEY_ENV" sops --decrypt "$SECRET_FILE" >/dev/null 2>&1; then
    CAN_DECRYPT=true
  fi
fi

if [ "$CAN_DECRYPT" = true ]; then
  echo "==> Re-encrypting secrets with newly updated recipient list..."
  SOPS_AGE_KEY_FILE="$SOPS_KEY_ENV" sops updatekeys -y "$SECRET_FILE"
  echo "🎉 Secret successfully re-encrypted! Current host is now fully authorized."

  if [ "$DO_COMMIT" = true ]; then
    echo "==> Committing updated .sops.yaml and secrets..."
    git -C "${REPO_ROOT}" add "${SOPS_CONFIG}" "${SECRET_FILE}"
    git -C "${REPO_ROOT}" commit -m "chore(sops): authorize host SSH key for $(hostname -s 2>/dev/null || echo 'new host')"
    echo "✅ Changes committed to git."
  fi
else
  echo ""
  echo "ℹ️  NOTICE: Host SSH key added to ${SOPS_CONFIG}."
  echo "👉 Because this is a new machine without pre-existing decryption keys,"
  echo "   please run one of the following to complete authorization:"
  echo "   1. Commit and push .sops.yaml to GitHub: git add .sops.yaml && git commit -m 'chore(sops): add host key' && git push"
  echo "   2. On an authorized machine (e.g. envy): git pull && sops updatekeys -y secrets/tailscale.enc.yaml && git commit -am 'chore: re-encrypt' && git push"
  echo "   3. Or allow the automated GitHub Actions rotation workflow to re-encrypt secrets for all recipients."
fi

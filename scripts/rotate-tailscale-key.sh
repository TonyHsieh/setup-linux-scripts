#!/usr/bin/env bash
# ==============================================================================
# rotate-tailscale-key.sh
# Rotates the Tailscale auth key via Tailscale OAuth API,
# re-encrypts secrets/tailscale.enc.yaml with SOPS,
# and updates ~/.local/share/local-services/.env.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOPS_CONFIG="${REPO_ROOT}/.sops.yaml"
SECRET_FILE="${REPO_ROOT}/secrets/tailscale.enc.yaml"

DO_COMMIT=false
for arg in "$@"; do
  case "$arg" in
    --commit)
      DO_COMMIT=true
      shift
      ;;
  esac
done

# 1. Ensure sops, curl, jq are available
for tool in sops curl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    if [ -x "${HOME}/.nix-profile/bin/$tool" ]; then
      export PATH="${HOME}/.nix-profile/bin:${PATH}"
    else
      echo "❌ Required tool '$tool' is not installed or not in PATH." >&2
      exit 1
    fi
  fi
done

# 2. Resolve OAuth Client ID and Secret
CLIENT_ID="${TS_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${TS_OAUTH_CLIENT_SECRET:-}"

# Fallback: check if existing secrets/tailscale.enc.yaml has credentials
if [ -z "${CLIENT_ID}" ] || [ -z "${CLIENT_SECRET}" ]; then
  if [ -f "${SECRET_FILE}" ]; then
    if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
      if [ -f "${HOME}/.config/sops/age/keys.txt" ]; then
        export SOPS_AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
      elif [ -f "${HOME}/.ssh/id_ed25519" ]; then
        export SOPS_AGE_KEY_FILE="${HOME}/.ssh/id_ed25519"
      fi
    fi
    [ -z "${CLIENT_ID}" ] && CLIENT_ID="$(sops --decrypt --extract '["tailscale"]["oauth_client_id"]' "${SECRET_FILE}" 2>/dev/null || true)"
    [ -z "${CLIENT_SECRET}" ] && CLIENT_SECRET="$(sops --decrypt --extract '["tailscale"]["oauth_client_secret"]' "${SECRET_FILE}" 2>/dev/null || true)"
  fi
fi

if [ -z "${CLIENT_ID}" ] || [ -z "${CLIENT_SECRET}" ]; then
  echo "❌ Tailscale OAuth credentials not found." >&2
  echo "" >&2
  echo "Please set your Tailscale OAuth Client ID and Secret in your environment or ~/.bashrc.local:" >&2
  echo '  export TS_OAUTH_CLIENT_ID="k..."' >&2
  echo '  export TS_OAUTH_CLIENT_SECRET="tskey-client-..."' >&2
  echo "" >&2
  echo "👉 Create one at: https://login.tailscale.com/admin/settings/oauth (Scope: keys:write)" >&2
  exit 1
fi

echo "==> Requesting temporary access token from Tailscale OAuth API..."
TOKEN_RESP="$(curl -s -f -X POST "https://api.tailscale.com/api/v2/oauth/token" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" 2>&1 || true)"

ACCESS_TOKEN="$(echo "${TOKEN_RESP}" | jq -r '.access_token // empty')"
if [ -z "${ACCESS_TOKEN}" ]; then
  echo "❌ Failed to obtain Tailscale OAuth access token." >&2
  echo "API Response: ${TOKEN_RESP}" >&2
  exit 1
fi

TS_TAG="${TS_TAG:-tag:local-services}"
if [[ "${TS_TAG}" != tag:* ]]; then
  TS_TAG="tag:${TS_TAG}"
fi

echo "==> Minting new 90-day reusable Tailscale auth key (tag: ${TS_TAG})..."
KEY_PAYLOAD="$(jq -n --arg tag "${TS_TAG}" '{
  capabilities: {
    devices: {
      create: {
        reusable: true,
        ephemeral: false,
        tags: [$tag]
      }
    }
  },
  expirySeconds: 7776000
}')"

KEY_RESP="$(curl -s -f -X POST "https://api.tailscale.com/api/v2/tailnet/-/keys" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${KEY_PAYLOAD}" 2>&1 || true)"

NEW_AUTH_KEY="$(echo "${KEY_RESP}" | jq -r '.key // empty')"
if [ -z "${NEW_AUTH_KEY}" ]; then
  echo "❌ Failed to generate Tailscale auth key from API." >&2
  echo "API Response: ${KEY_RESP}" >&2
  exit 1
fi

echo "   ✓ New auth key generated (${NEW_AUTH_KEY:0:15}...)"

# 3. Create unencrypted payload in memory / temp file and encrypt with SOPS
TEMP_RAW="$(mktemp /tmp/ts-secret-XXXXXX.yaml)"
trap 'rm -f "${TEMP_RAW}"' EXIT

cat << EOF > "${TEMP_RAW}"
tailscale:
  auth_key: "${NEW_AUTH_KEY}"
  oauth_client_id: "${CLIENT_ID}"
  oauth_client_secret: "${CLIENT_SECRET}"
EOF

mkdir -p "${REPO_ROOT}/secrets"
sops --filename-override "secrets/tailscale.enc.yaml" --encrypt "${TEMP_RAW}" > "${SECRET_FILE}"
rm -f "${TEMP_RAW}"
echo "   ✓ Re-encrypted ${SECRET_FILE} with SOPS multi-recipient keys"

# 4. Sync immediately to local .env (skipped in CI)
if [ -z "${CI:-}" ] && [ -x "${SCRIPT_DIR}/sync-tailscale-key.sh" ]; then
  "${SCRIPT_DIR}/sync-tailscale-key.sh" || true
fi

# 5. Optional git commit
if [ "${DO_COMMIT}" = true ]; then
  git -C "${REPO_ROOT}" add "${SECRET_FILE}"
  git -C "${REPO_ROOT}" commit -m "chore(tailscale): rotate Tailscale auth key via OAuth API"
  echo "   ✓ Committed updated secret to git"
fi

echo ""
echo "🎉 Tailscale auth key rotation complete! Valid for 90 days."

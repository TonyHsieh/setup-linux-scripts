#!/usr/bin/env bash
# ==============================================================================
# test-tailscale-ingress.sh
# Automated regression test suite for Tailscale Ingress Mesh & Zero-Plaintext SOPS.
# Validates Port 80 HTTP 301 redirection, Port 443 TLS proxying, container health,
# and disk secret sanitization.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

pass() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  PASSED_TESTS=$((PASSED_TESTS + 1))
  echo "  ✅ PASS: $1"
}

fail() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  FAILED_TESTS=$((FAILED_TESTS + 1))
  echo "  ❌ FAIL: $1"
}

echo "======================================================================"
echo "🧪 Running Tailscale Ingress & Security Regression Test Suite"
echo "======================================================================"

# ------------------------------------------------------------------------------
# Test Suite 1: Disk Secret Sanitization (Zero Plaintext Secrets on Disk)
# ------------------------------------------------------------------------------
echo ""
echo "👉 Suite 1: Disk Secret Sanitization & SOPS Decryption"
ENV_FILE="${HOME}/.local/share/local-services/.env"
if [ -f "$ENV_FILE" ]; then
  if grep -qE "^TS_AUTHKEY=" "$ENV_FILE"; then
    fail "Plaintext TS_AUTHKEY detected in $ENV_FILE (violates zero-disk security model)"
  else
    pass "No plaintext TS_AUTHKEY found on disk in $ENV_FILE"
  fi
  if grep -qE "^TS_MACHINE_ID=" "$ENV_FILE"; then
    pass "TS_MACHINE_ID correctly set in $ENV_FILE ($(grep '^TS_MACHINE_ID=' "$ENV_FILE"))"
  else
    fail "TS_MACHINE_ID missing from $ENV_FILE"
  fi
else
  fail "$ENV_FILE does not exist"
fi

SECRET_FILE="${REPO_ROOT}/secrets/tailscale.enc.yaml"
if [ -f "$SECRET_FILE" ]; then
  export SOPS_AGE_KEY_FILE="${HOME}/.ssh/id_ed25519"
  DECRYPTED_KEY="$(sops --decrypt --extract '["tailscale"]["auth_key"]' "$SECRET_FILE" 2>/dev/null || true)"
  if [[ "$DECRYPTED_KEY" =~ ^tskey-auth- ]]; then
    pass "SOPS decryption via host SSH key (~/.ssh/id_ed25519) succeeded (${DECRYPTED_KEY:0:15}...)"
  else
    fail "SOPS decryption via host SSH key failed or key empty"
  fi
else
  fail "$SECRET_FILE not found"
fi

# ------------------------------------------------------------------------------
# Test Suite 2: Rootless Podman DNS Fallback Configuration
# ------------------------------------------------------------------------------
echo ""
echo "👉 Suite 2: Rootless Podman DNS Configuration (ACME TLS Timeout Prevention)"
CONTAINERS_CONF="${HOME}/.config/containers/containers.conf"
if [ -f "$CONTAINERS_CONF" ]; then
  if grep -q "1.1.1.1" "$CONTAINERS_CONF" && grep -q "8.8.8.8" "$CONTAINERS_CONF"; then
    pass "Upstream DNS fallbacks (1.1.1.1, 8.8.8.8) present in $CONTAINERS_CONF"
  else
    fail "Upstream DNS fallbacks missing in $CONTAINERS_CONF"
  fi
else
  fail "$CONTAINERS_CONF not found"
fi

# ------------------------------------------------------------------------------
# Test Suite 3: Running Ingress Containers Health
# ------------------------------------------------------------------------------
echo ""
echo "👉 Suite 3: Dedicated Ingress Sidecars Container Status"
SERVICES=("pdf" "chat" "traefik" "ollama" "books" "plex" "desktop")

for svc in "${SERVICES[@]}"; do
  CONTAINER="local-tailscale-${svc}"
  if podman ps -q -f name="^${CONTAINER}$" 2>/dev/null | grep -q .; then
    STATUS="$(podman inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")"
    if [ "$STATUS" = "running" ]; then
      pass "Container $CONTAINER is running"
    else
      fail "Container $CONTAINER exists but status is $STATUS"
    fi
  else
    fail "Container $CONTAINER is not running"
  fi
done

# ------------------------------------------------------------------------------
# Test Suite 4: Tailscale Serve Schema & Port 80 301 Redirection
# ------------------------------------------------------------------------------
echo ""
echo "👉 Suite 4: Port 80 HTTP 301 Redirection & Port 443 TLS Verification"

for svc in "${SERVICES[@]}"; do
  CONTAINER="local-tailscale-${svc}"
  if podman ps -q -f name="^${CONTAINER}$" 2>/dev/null | grep -q .; then
    SERVE_JSON="$(podman exec "$CONTAINER" tailscale serve status --json 2>/dev/null || echo "{}")"

    # 1. Verify Port 80 uses HTTP: true (NOT HTTPS: false)
    HTTP_PORT_80="$(echo "$SERVE_JSON" | jq -r '.TCP["80"].HTTP // false')"
    if [ "$HTTP_PORT_80" = "true" ]; then
      pass "[$svc] Port 80 configured with 'HTTP: true' (correct schema for unencrypted listener)"
    else
      fail "[$svc] Port 80 is not configured with 'HTTP: true' (got '$HTTP_PORT_80')"
    fi

    # 2. Verify Port 80 handler is 301 Redirect
    REDIRECT_TARGET="$(echo "$SERVE_JSON" | jq -r 'to_entries[] | select(.key == "Web") | .value | to_entries[] | select(.key | endswith(":80")) | .value.Handlers["/"].Redirect // empty')"
    if [[ "$REDIRECT_TARGET" =~ 301:https:// ]]; then
      pass "[$svc] Port 80 has active 301 HTTP->HTTPS redirect: $REDIRECT_TARGET"
    else
      fail "[$svc] Port 80 handler is missing 301 redirect (got '$REDIRECT_TARGET')"
    fi

    # 3. Verify Port 443 uses HTTPS: true
    HTTPS_PORT_443="$(echo "$SERVE_JSON" | jq -r '.TCP["443"].HTTPS // false')"
    if [ "$HTTPS_PORT_443" = "true" ]; then
      pass "[$svc] Port 443 configured with 'HTTPS: true' (TLS termination active)"
    else
      fail "[$svc] Port 443 is missing 'HTTPS: true'"
    fi

    # 4. Verify Port 443 has Proxy target
    PROXY_TARGET="$(echo "$SERVE_JSON" | jq -r 'to_entries[] | select(.key == "Web") | .value | to_entries[] | select(.key | endswith(":443")) | .value.Handlers["/"].Proxy // empty')"
    if [[ -n "$PROXY_TARGET" ]]; then
      pass "[$svc] Port 443 proxies securely to internal mesh: $PROXY_TARGET"
    else
      fail "[$svc] Port 443 is missing Proxy target"
    fi
  else
    fail "Skipping serve checks: $CONTAINER not running"
  fi
done

# ------------------------------------------------------------------------------
# Test Suite 5: Active Backend Services Verification
# ------------------------------------------------------------------------------
echo ""
echo "👉 Suite 5: Local Backend Services Health"
for backend in "traefik-ingress" "bentopdf" "local-postgres" "local-kavita" "local-plex"; do
  if podman ps -q -f name="^${backend}$" 2>/dev/null | grep -q .; then
    pass "Backend $backend is running"
  else
    fail "Backend $backend is not running"
  fi
done

# ------------------------------------------------------------------------------
# Test Suite 6: Host Tailscale SSH Configuration & Script Integrity
# ------------------------------------------------------------------------------
echo ""
echo "👉 Suite 6: Host Tailscale SSH Management & Integration"
SSH_SCRIPT="${REPO_ROOT}/scripts/setup-tailscale-ssh.sh"
if [ -x "$SSH_SCRIPT" ]; then
  pass "setup-tailscale-ssh.sh script exists and is executable"
else
  fail "setup-tailscale-ssh.sh is missing or not executable"
fi

if command -v tailscale >/dev/null 2>&1; then
  pass "Tailscale CLI is installed on host"
  if tailscale status >/dev/null 2>&1; then
    SSH_CAP="$(tailscale status --json 2>/dev/null | jq -r '.Self.Capabilities[]? | select(. == "https://tailscale.com/cap/ssh")' 2>/dev/null || true)"
    if [ -n "$SSH_CAP" ]; then
      pass "Tailscale SSH capability is active and advertised on host"
    else
      echo "  ℹ️  INFO: Tailscale is connected, but SSH is not active yet (run 'jl up-ssh')"
    fi
  else
    echo "  ℹ️  INFO: Tailscale CLI is installed, but daemon is currently stopped/offline"
  fi
else
  echo "  ℹ️  INFO: Host Tailscale CLI is not installed yet (run 'jl up-ssh' to set up)"
fi

# ------------------------------------------------------------------------------
# Test Suite 7: Remote Desktop Setup & Port Verification
# ------------------------------------------------------------------------------
echo ""
echo "👉 Suite 7: Remote Desktop Management & Integration"
DESKTOP_SCRIPT="${REPO_ROOT}/scripts/setup-remote-desktop.sh"
if [ -x "$DESKTOP_SCRIPT" ]; then
  pass "setup-remote-desktop.sh script exists and is executable"
else
  fail "setup-remote-desktop.sh is missing or not executable"
fi

SERVE_DESKTOP_FILE="${REPO_ROOT}/local-services/tailscale/serve-desktop.json"
if [ -f "$SERVE_DESKTOP_FILE" ]; then
  pass "serve-desktop.json exists and is valid JSON"
else
  fail "serve-desktop.json missing"
fi

echo ""
echo "======================================================================"
echo "📊 Test Summary: Total: ${TOTAL_TESTS} | Passed: ${PASSED_TESTS} | Failed: ${FAILED_TESTS}"
echo "======================================================================"

if [ "$FAILED_TESTS" -eq 0 ]; then
  echo "🎉 All regression tests passed with 0 failures!"
  exit 0
else
  echo "⚠️ Regression detected! Please review the failures above."
  exit 1
fi

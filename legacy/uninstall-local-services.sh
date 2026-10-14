#!/usr/bin/env bash
# ==============================================================================
# uninstall-local-services.sh
# Purpose: Idempotent uninstallation and teardown of local service mesh created
#          by install-local-services.sh (Traefik v3, BentoPDF, Podman stack).
# Target: CachyOS / Arch Linux, WSL2-Ubuntu / Debian Linux, and macOS
# ==============================================================================
set -euo pipefail

SERVICE_DIR="$HOME/.local/share/local-services"
COMPOSE_FILE="$SERVICE_DIR/docker-compose.yml"

echo "==> Teardown of Local Service Mesh"

# 1. Stop and remove Podman container stack
if [ -f "$COMPOSE_FILE" ] && command -v podman-compose >/dev/null 2>&1; then
  echo "==> Stopping local container mesh via podman-compose"
  podman-compose -f "$COMPOSE_FILE" down || true
else
  echo "==> No active docker-compose configuration found or podman-compose not installed."
fi

# 2. Optionally remove local-services directory
if [ -d "$SERVICE_DIR" ]; then
  if [ -t 0 ]; then
    read -rp "Do you want to delete the local services configuration directory at $SERVICE_DIR? (y/N) " confirm_del
    if [[ "$confirm_del" =~ ^[Yy]$ ]]; then
      echo "==> Removing $SERVICE_DIR"
      rm -rf "$SERVICE_DIR"
    else
      echo "==> Preserving $SERVICE_DIR"
    fi
  else
    echo "==> Removing configuration directory $SERVICE_DIR (non-interactive session)"
    rm -rf "$SERVICE_DIR"
  fi
fi

# 3. Clean up 'jl' alias from ~/.bashrc
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && grep -q "alias jl=" "$BASHRC" 2>/dev/null; then
  echo "==> Removing 'jl' alias from ~/.bashrc"
  sed -i '/# Local Service Mesh Alias (just task runner)/d' "$BASHRC" || true
  sed -i '/alias jl=/d' "$BASHRC" || true
fi

echo ""
echo "======================================================================"
echo "✓ Local services uninstallation complete!"
echo "👉 Note: Packages (podman, mkcert, just) were preserved."
echo "   To reload your shell, run: exec bash"
echo "======================================================================"

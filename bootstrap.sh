#!/usr/bin/env bash
# ==============================================================================
# bootstrap.sh
# Purpose: Idempotent bootstrap for Declarative Nix & Home Manager across machines
# Targets: WSL2 (Ubuntu), CachyOS / Arch Linux, macOS (Darwin)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="switch"
INSTALL_HOST_DEPS=false
TARGET_OVERRIDE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|--build)
      ACTION="build"
      shift
      ;;
    --with-host-deps|--host-deps|--all)
      INSTALL_HOST_DEPS=true
      shift
      ;;
    --profile)
      TARGET_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./bootstrap.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --build, --dry-run      Build the Home Manager generation without activating it"
      echo "  --with-host-deps, --all Install host system prerequisites (Podman, port 80 sysctl, mkcert CA)"
      echo "  --profile <name>        Manually specify profile (wsl, cachyos, darwin)"
      echo "  -h, --help              Show this help message"
      exit 0
      ;;
    *)
      TARGET_OVERRIDE="$1"
      shift
      ;;
  esac
done

echo "==> ❄️  Starting Declarative Nix Environment Bootstrap..."

# 0. Optional: Install host system prerequisites (Podman, rootless sockets, sysctl)
install_host_dependencies() {
  echo "==> Setting up host system prerequisites (Podman & container runtime)..."
  if [ "$(uname)" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
      echo "==> Installing podman and podman-compose via Homebrew..."
      brew install podman podman-compose
      if ! podman machine list 2>/dev/null | grep -q "Running"; then
        echo "==> Initializing Podman Machine on macOS..."
        if ! podman machine list 2>/dev/null | grep -q "podman-machine-default"; then
          podman machine init
        fi
        podman machine start
      fi
    else
      echo "⚠️ Warning: Homebrew not found. Please install Homebrew to install Podman on macOS."
    fi
  elif command -v pacman >/dev/null 2>&1; then
    echo "==> Installing podman and podman-compose via pacman..."
    sudo pacman -S --needed --noconfirm podman podman-compose
  elif command -v apt-get >/dev/null 2>&1; then
    echo "==> Installing podman and podman-compose via apt..."
    sudo apt-get update -y
    sudo apt-get install -y podman podman-compose
  fi

  # Linux & WSL: Enable user-level Podman socket and unprivileged ports
  if [ "$(uname)" != "Darwin" ]; then
    echo "==> Enabling rootless Podman user systemd socket..."
    systemctl --user enable --now podman.socket 2>/dev/null || true

    if command -v sysctl >/dev/null 2>&1; then
      echo "==> Enabling unprivileged port binding (port 80 & 443 for Traefik)..."
      if [ -w /etc/sysctl.d ]; then
        echo "net.ipv4.ip_unprivileged_port_start=80" > /etc/sysctl.d/99-podman-ports.conf 2>/dev/null || true
        sysctl --system >/dev/null 2>&1 || true
      elif command -v sudo >/dev/null 2>&1; then
        echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-podman-ports.conf >/dev/null 2>&1 || true
        sudo sysctl --system >/dev/null 2>&1 || true
      fi
    fi
  fi
}

if [ "$INSTALL_HOST_DEPS" = true ]; then
  install_host_dependencies
fi

# 1. Ensure Nix is installed
if ! command -v nix >/dev/null 2>&1 && [ ! -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && [ ! -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  echo "==> Nix not found. Installing Nix via Determinate Systems Installer..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
else
  echo "   ✓ Nix installation detected."
fi

# Source Nix profile for current execution session if present
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck source=/dev/null
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

if [ -d "$HOME/.nix-profile/bin" ]; then
  export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# 1.5. Ensure Nix Flakes and nix-command are enabled permanently
mkdir -p "$HOME/.config/nix"
if [ ! -f "$HOME/.config/nix/nix.conf" ] || ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf"; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
fi
export NIX_CONFIG="experimental-features = nix-command flakes"

# 1.6. Clean up legacy imperative 'nix profile' packages to prevent Home Manager collisions
if nix profile list 2>/dev/null | grep -q "devenv"; then
  echo "==> Cleaning up legacy imperative devenv from nix profile (now managed declaratively)..."
  nix profile remove devenv 2>/dev/null || true
fi

# 2. Auto-detect environment profile if not manually overridden
if [ -n "${TARGET_OVERRIDE:-}" ]; then
  TARGET_PROFILE="$TARGET_OVERRIDE"
elif [ "$(uname)" = "Darwin" ]; then
  TARGET_PROFILE="darwin"
elif grep -qsi Microsoft /proc/version 2>/dev/null; then
  TARGET_PROFILE="wsl"
elif [ "$USER" = "thsieh01" ] || command -v pacman >/dev/null 2>&1; then
  TARGET_PROFILE="cachyos"
else
  TARGET_PROFILE="wsl"
fi

echo "   ✓ Target Profile: '$TARGET_PROFILE' (User: $USER, Host: $(hostname))"

# 3. Ensure Git tracks new files in the workspace (Nix Flakes ignores untracked files)
if [ -d "$SCRIPT_DIR/.git" ]; then
  echo "==> Updating Git index for Nix Flake evaluation..."
  git -C "$SCRIPT_DIR" add -N flake.nix home/ modules/ templates/ dotfiles/ local-services/ 2>/dev/null || true
fi

# 4. Execute Home Manager action (build or switch)
echo "==> Running Home Manager ($ACTION) for profile: .#${TARGET_PROFILE}..."
if [ "$ACTION" = "build" ]; then
  nix run --extra-experimental-features "nix-command flakes" home-manager -- build --flake "${SCRIPT_DIR}#${TARGET_PROFILE}"
  echo ""
  echo "🎉 Dry-run build successful! Result symlink created at ./result"
else
  BACKUP_EXT="backup-$(date +%Y%m%d%H%M%S)"
  nix run --extra-experimental-features "nix-command flakes" home-manager -- switch --flake "${SCRIPT_DIR}#${TARGET_PROFILE}" -b "$BACKUP_EXT"

  # 5. Bootstrap LazyVim starter if Neovim config is not yet initialized
  if [ ! -f "$HOME/.config/nvim/init.lua" ]; then
    echo "==> Bootstrapping LazyVim starter template into ~/.config/nvim..."
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim" 2>/dev/null || true
    rm -rf "$HOME/.config/nvim/.git"
  fi

  # 6. Bootstrap SOPS age key pair if missing
  AGE_KEY_DIR="$HOME/.config/sops/age"
  AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"
  if [ ! -f "$AGE_KEY_FILE" ]; then
    if command -v age-keygen >/dev/null 2>&1 || [ -x "$HOME/.nix-profile/bin/age-keygen" ]; then
      echo "==> Generating age key pair for SOPS at $AGE_KEY_FILE..."
      mkdir -p "$AGE_KEY_DIR"
      chmod 700 "$AGE_KEY_DIR"
      "${HOME}/.nix-profile/bin/age-keygen" -o "$AGE_KEY_FILE" 2>/dev/null || age-keygen -o "$AGE_KEY_FILE"
      chmod 600 "$AGE_KEY_FILE"
    fi
  fi

  # 7. Host SSL CA Trust & Local Service Certificates (if mkcert is available)
  if command -v mkcert >/dev/null 2>&1 || [ -x "$HOME/.nix-profile/bin/mkcert" ]; then
    echo "==> Registering local mkcert CA with system trust store..."
    "${HOME}/.nix-profile/bin/mkcert" -install 2>/dev/null || mkcert -install 2>/dev/null || true

    # Automatically generate *.localhost SSL certificates if local-services mesh is present
    if [ -f "$HOME/.local/share/local-services/justfile" ]; then
      echo "==> Ensuring local wildcard SSL certificates exist (*.localhost)..."
      "${HOME}/.nix-profile/bin/just" -f "$HOME/.local/share/local-services/justfile" certs 2>/dev/null || true
    fi
  fi

  echo ""
  echo "🎉 Environment successfully activated via Nix Home Manager!"
  echo "👉 Your declarative CLI packages are now linked into ~/.nix-profile/bin"
  echo "👉 Existing dotfiles backed up with extension: .$BACKUP_EXT"
  echo "👉 Reload your shell to enjoy the updated environment: exec bash"
  if command -v podman >/dev/null 2>&1; then
    echo "👉 Local container mesh ready: run 'jl up' to start Traefik, BentoPDF, & Postgres!"
  else
    echo "👉 Tip: To enable the local container mesh (Traefik, BentoPDF, Postgres), run: ./bootstrap.sh --with-host-deps"
  fi
fi

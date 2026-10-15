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
CLEANUP_MODE="prompt" # options: "prompt", "auto", "skip"

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
    --clean|--cleanup)
      CLEANUP_MODE="auto"
      shift
      ;;
    --no-cleanup|--skip-cleanup)
      CLEANUP_MODE="skip"
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
      echo "  --cleanup, --clean      Automatically clean up detected legacy artifacts after verification"
      echo "  --no-cleanup            Skip detection and cleanup of legacy deployment artifacts"
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
    echo "==> Synchronizing pacman databases and installing podman & podman-compose..."
    if ! sudo pacman -Sy --needed --noconfirm podman podman-compose; then
      echo "⚠️ Pacman download failed (stale mirrors or database). Refreshing mirrorlist and retrying..."
      if command -v cachyos-rate-mirrors >/dev/null 2>&1; then
        sudo cachyos-rate-mirrors || true
      elif command -v rate-mirrors >/dev/null 2>&1; then
        sudo rate-mirrors arch | sudo tee /etc/pacman.d/mirrorlist || true
      fi
      sudo pacman -Syy --needed --noconfirm podman podman-compose
    fi
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

# Global detection state
DETECTED_DUPLICATE_BINS=()
DETECTED_DOTFILE_BACKUPS=()
DETECTED_LEGACY_DIRS=()
DETECTED_NIX_PROFILE_PKGS=()
DETECTED_OLD_GENERATIONS=0

detect_existing_deployments() {
  echo "==> 🔍 Scanning for existing / legacy deployment artifacts..."
  DETECTED_DUPLICATE_BINS=()
  DETECTED_DOTFILE_BACKUPS=()
  DETECTED_LEGACY_DIRS=()
  DETECTED_NIX_PROFILE_PKGS=()
  DETECTED_OLD_GENERATIONS=0

  # 1. Check for legacy/duplicate binaries in /usr/local/bin and ~/.local/bin
  local candidate_bins=(
    argocd flux minikube nvim k9s sops kind yq kubectl starship hermes ha opencode oc devenv
  )
  for b in "${candidate_bins[@]}"; do
    if [ -f "/usr/local/bin/$b" ]; then
      DETECTED_DUPLICATE_BINS+=("/usr/local/bin/$b")
    fi
    if [ -f "$HOME/.local/bin/$b" ]; then
      DETECTED_DUPLICATE_BINS+=("$HOME/.local/bin/$b")
    fi
  done

  # 2. Check for legacy dotfile backups
  for f in "$HOME/.bashrc.bak" "$HOME/.tmux.conf.bak" "$HOME/.config/starship.toml.bak"; do
    if [ -f "$f" ]; then
      DETECTED_DOTFILE_BACKUPS+=("$f")
    fi
  done
  while IFS= read -r f; do
    if [ -n "$f" ]; then
      DETECTED_DOTFILE_BACKUPS+=("$f")
    fi
  done < <(find "$HOME" -maxdepth 1 \( -name ".bashrc.backup-*" -o -name ".tmux.conf.backup-*" \) 2>/dev/null || true)

  # 3. Check for obsolete residue directories superseded by declarative Nix
  local legacy_dirs=(
    "$HOME/.local/share/blesh"
    "$HOME/.tmux/plugins/tpm"
    "$HOME/.local/share/lunarvim"
    "$HOME/.config/lvim"
  )
  for d in "${legacy_dirs[@]}"; do
    if [ -d "$d" ]; then
      DETECTED_LEGACY_DIRS+=("$d")
    fi
  done

  # 4. Check for imperative nix profile packages (e.g. devenv)
  if command -v nix >/dev/null 2>&1; then
    while IFS= read -r line; do
      if [ -n "$line" ]; then
        DETECTED_NIX_PROFILE_PKGS+=("$line")
      fi
    done < <(nix profile list 2>/dev/null | grep -E "devenv" | awk '{print $1}' || true)
  fi

  # 5. Check for existing Home Manager generations
  if command -v home-manager >/dev/null 2>&1; then
    DETECTED_OLD_GENERATIONS=$(home-manager generations 2>/dev/null | wc -l || echo 0)
  fi

  local total_found=$(( ${#DETECTED_DUPLICATE_BINS[@]} + ${#DETECTED_DOTFILE_BACKUPS[@]} + ${#DETECTED_LEGACY_DIRS[@]} + ${#DETECTED_NIX_PROFILE_PKGS[@]} ))
  if [ "$total_found" -gt 0 ]; then
    echo "   ⚠️  Detected $total_found legacy / existing artifact(s) from previous installations."
  else
    echo "   ✓ No conflicting legacy artifacts found."
  fi
}

verify_deployment() {
  echo ""
  echo "==> 🧪 Running self-test to verify new Declarative Nix & Home Manager environment..."
  local test_failures=0

  # Check core CLI binaries in ~/.nix-profile/bin
  local tools_to_check=(starship git tmux nvim direnv just)
  for tool in "${tools_to_check[@]}"; do
    if [ -x "$HOME/.nix-profile/bin/$tool" ]; then
      local version_str
      version_str=$("$HOME/.nix-profile/bin/$tool" --version 2>/dev/null | head -n1 || echo "ready")
      echo "   ✓ Tool verified: $tool ($version_str)"
    else
      echo "   ⚠️ Warning: $tool not found in ~/.nix-profile/bin"
      test_failures=$((test_failures + 1))
    fi
  done

  # Check shell dotfiles
  if [ -L "$HOME/.bashrc" ] || grep -qi "home-manager" "$HOME/.bashrc" 2>/dev/null; then
    echo "   ✓ Shell configuration: ~/.bashrc managed by Home Manager"
  elif [ -f "$HOME/.bashrc" ]; then
    echo "   ✓ Shell configuration: ~/.bashrc active"
  fi

  # Check Tier 2 container mesh configs
  if [ -f "$HOME/.local/share/local-services/docker-compose.yml" ]; then
    echo "   ✓ Container mesh: ~/.local/share/local-services/docker-compose.yml linked"
  else
    echo "   ⚠️ Warning: Local services compose file missing from ~/.local/share/local-services"
    test_failures=$((test_failures + 1))
  fi

  if [ -f "$HOME/.local/share/local-services/justfile" ]; then
    echo "   ✓ Local services task runner: ~/.local/share/local-services/justfile linked"
  fi

  if [ "$test_failures" -eq 0 ]; then
    echo "🎉 Verification passed! All core tools and configurations are active and healthy."
    return 0
  else
    echo "⚠️ Environment verification completed with $test_failures warning(s)."
    return 1
  fi
}

offer_and_run_cleanup() {
  local current_backup="${1:-}"

  # If running in build/dry-run mode, report only
  if [ "$ACTION" = "build" ]; then
    local total_found=$(( ${#DETECTED_DUPLICATE_BINS[@]} + ${#DETECTED_DOTFILE_BACKUPS[@]} + ${#DETECTED_LEGACY_DIRS[@]} ))
    if [ "$total_found" -gt 0 ]; then
      echo ""
      echo "ℹ️  Dry-run build mode: Skipping cleanup. The following legacy artifacts were detected:"
      for b in "${DETECTED_DUPLICATE_BINS[@]}"; do echo "   - Binary: $b"; done
      for f in "${DETECTED_DOTFILE_BACKUPS[@]}"; do echo "   - Backup: $f"; done
      for d in "${DETECTED_LEGACY_DIRS[@]}"; do echo "   - Directory: $d"; done
    fi
    return 0
  fi

  if [ "$CLEANUP_MODE" = "skip" ]; then
    echo ""
    echo "ℹ️  Legacy cleanup skipped per command-line flag (--no-cleanup)."
    return 0
  fi

  # Filter out the backup just created in this run from cleanup list
  local backups_to_clean=()
  for f in "${DETECTED_DOTFILE_BACKUPS[@]}"; do
    if [ -n "$current_backup" ] && [[ "$f" == *"$current_backup"* ]]; then
      continue
    fi
    backups_to_clean+=("$f")
  done

  local total_detected=$(( ${#DETECTED_DUPLICATE_BINS[@]} + ${#backups_to_clean[@]} + ${#DETECTED_LEGACY_DIRS[@]} ))
  if [ "$total_detected" -eq 0 ]; then
    echo ""
    echo "==> 🧹 No legacy deployment residue detected. System is clean!"
    return 0
  fi

  echo ""
  echo "======================================================================"
  echo "🧹 Existing / Legacy Deployment Artifacts Detected"
  echo "======================================================================"
  echo "The new declarative environment is verified and operational."
  echo "The following legacy files/directories from prior setups were found:"
  echo ""

  if [ ${#DETECTED_DUPLICATE_BINS[@]} -gt 0 ]; then
    echo "📦 Duplicate / Shadowed Host Binaries (can conflict with Nix packages):"
    for b in "${DETECTED_DUPLICATE_BINS[@]}"; do
      echo "   • $b"
    done
  fi

  if [ ${#backups_to_clean[@]} -gt 0 ]; then
    echo "📄 Stale Dotfile Backups:"
    for f in "${backups_to_clean[@]}"; do
      echo "   • $f"
    done
  fi

  if [ ${#DETECTED_LEGACY_DIRS[@]} -gt 0 ]; then
    echo "📁 Obsolete Residue Directories (superseded by Nix):"
    for d in "${DETECTED_LEGACY_DIRS[@]}"; do
      echo "   • $d"
    done
  fi

  if [ "$DETECTED_OLD_GENERATIONS" -gt 1 ]; then
    echo "🔄 Existing Nix Generations: $DETECTED_OLD_GENERATIONS generations exist."
  fi
  echo "======================================================================"

  local do_cleanup=false
  if [ "$CLEANUP_MODE" = "auto" ]; then
    do_cleanup=true
  elif [ -t 0 ]; then
    echo ""
    read -rp "Would you like to clean up these legacy / duplicate artifacts now? (y/N) " confirm_cleanup
    if [[ "$confirm_cleanup" =~ ^[Yy]$ ]]; then
      do_cleanup=true
    fi
  else
    echo ""
    echo "ℹ️  Non-interactive session detected. Skipping cleanup prompt."
    echo "👉 To clean up detected legacy artifacts automatically, re-run with: ./bootstrap.sh --cleanup"
    return 0
  fi

  if [ "$do_cleanup" = true ]; then
    echo "==> Cleaning up detected legacy deployment artifacts..."

    # 1. Clean dotfile backups
    for f in "${backups_to_clean[@]}"; do
      if [ -f "$f" ]; then
        rm -f "$f"
        echo "   ✓ Removed: $f"
      fi
    done

    # 2. Clean obsolete directories
    for d in "${DETECTED_LEGACY_DIRS[@]}"; do
      if [ -d "$d" ]; then
        rm -rf "$d"
        echo "   ✓ Removed directory: $d"
      fi
    done

    # 3. Clean duplicate binaries in ~/.local/bin and /usr/local/bin
    local user_bins=()
    local sudo_bins=()
    for b in "${DETECTED_DUPLICATE_BINS[@]}"; do
      if [[ "$b" == "$HOME"* ]]; then
        user_bins+=("$b")
      else
        sudo_bins+=("$b")
      fi
    done

    for ub in "${user_bins[@]}"; do
      if [ -f "$ub" ]; then
        rm -f "$ub"
        echo "   ✓ Removed: $ub"
      fi
    done

    if [ ${#sudo_bins[@]} -gt 0 ]; then
      echo "==> Removing duplicate system binaries in /usr/local/bin (requires sudo)..."
      if command -v sudo >/dev/null 2>&1; then
        sudo rm -f "${sudo_bins[@]}"
        echo "   ✓ Removed: ${sudo_bins[*]}"
      else
        echo "⚠️ Sudo not available. Please remove manually: rm -f ${sudo_bins[*]}"
      fi
    fi

    echo ""
    echo "🎉 Cleanup completed successfully! Your system is now running cleanly on Declarative Nix."
  else
    echo ""
    echo "==> Skipping cleanup. All legacy files and backups have been preserved."
    echo "👉 You can run cleanup at any time using: ./bootstrap.sh --cleanup"
  fi
}

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
elif [ "$USER" = "thsieh01" ]; then
  TARGET_PROFILE="cachyos-thsieh01"
elif [ "$USER" = "thsieh" ] || command -v pacman >/dev/null 2>&1; then
  TARGET_PROFILE="cachyos"
else
  TARGET_PROFILE="wsl"
fi

echo "   ✓ Target Profile: '$TARGET_PROFILE' (User: $USER, Host: $(hostname))"

# 2.5 Scan for existing deployments before making changes
detect_existing_deployments

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
  offer_and_run_cleanup ""
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

    # Register Root CA in Windows Trust Store if running in WSL2
    if grep -qsi Microsoft /proc/version 2>/dev/null; then
      ROOT_CA="$HOME/.local/share/mkcert/rootCA.pem"
      if [ -f "$ROOT_CA" ] && command -v wslpath >/dev/null 2>&1; then
        WIN_CA="$(wslpath -w "$ROOT_CA" 2>/dev/null || true)"
        WIN_PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
        if [ -n "$WIN_CA" ] && [ -x "$WIN_PS" ]; then
          echo "==> Attempting to register Root CA in Windows Certificate Store (UAC prompt may appear)..."
          "$WIN_PS" -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command','Import-Certificate -FilePath \"$WIN_CA\" -CertStoreLocation Cert:\LocalMachine\Root'" 2>/dev/null || true
        fi
      fi
    fi
  fi

  # 7.5. Bootstrap local secret overrides (~/.bashrc.local) template if missing
  if [ ! -f "$HOME/.bashrc.local" ]; then
    echo "==> Creating initial ~/.bashrc.local credential stubs template..."
    cat << 'EOF' > "$HOME/.bashrc.local"
# ~/.bashrc.local - Machine-specific & Private Environment Overrides
# This file is sourced by ~/.bashrc and is ignored by Git.

# --- ☁️ Hosted AI Agent Providers ---
# Google Gemini (https://aistudio.google.com/app/apikey)
# export GEMINI_API_KEY="AIzaSy..."
# export GOOGLE_GENERATIVE_AI_API_KEY="$GEMINI_API_KEY"

# OpenRouter Unified Multi-Model Gateway (https://openrouter.ai/keys)
# export OPENROUTER_API_KEY="sk-or-v1-..."

# Groq Ultra-Low Latency Inference (https://console.groq.com/keys)
# export GROQ_API_KEY="gsk_..."

# --- 🦙 Local Containerized LLM (Ollama / LocalAI / llama.cpp) ---
# Uncomment to direct OpenCode or LiteLLM agents to your local mesh:
# export OPENAI_BASE_URL="http://localhost:11434/v1"
# export OPENAI_API_KEY="ollama"
EOF
    chmod 600 "$HOME/.bashrc.local"
  fi

  echo ""
  echo "🎉 Environment successfully activated via Nix Home Manager!"
  echo "👉 Your declarative CLI packages are now linked into ~/.nix-profile/bin"
  echo "👉 Existing dotfiles backed up with extension: .$BACKUP_EXT"

  # 8. Run Verification Self-Test
  verify_deployment

  # 9. Offer to clean up detected legacy / existing artifacts
  offer_and_run_cleanup "$BACKUP_EXT"

  echo ""
  echo "👉 Reload your shell to enjoy the updated environment: exec bash"
  if [ "$DETECTED_OLD_GENERATIONS" -gt 1 ]; then
    echo "👉 Disk tip: To prune old Nix generations and reclaim store disk space, run: nix-collect-garbage -d"
  fi
  if grep -qsi Microsoft /proc/version 2>/dev/null; then
    ROOT_CA="$HOME/.local/share/mkcert/rootCA.pem"
    if [ -f "$ROOT_CA" ] && command -v wslpath >/dev/null 2>&1; then
      WIN_CA="$(wslpath -w "$ROOT_CA" 2>/dev/null || true)"
      echo "👉 Windows SSL Notice: If browser shows untrusted certs, run this in Admin PowerShell:"
      echo "   Import-Certificate -FilePath \"$WIN_CA\" -CertStoreLocation Cert:\LocalMachine\Root"
    fi
  fi
  if command -v podman >/dev/null 2>&1; then
    echo "👉 Local container mesh ready: run 'jl up' to start Traefik, BentoPDF, & Postgres!"
  else
    echo "👉 Tip: To enable the local container mesh (Traefik, BentoPDF, Postgres), run: ./bootstrap.sh --with-host-deps"
  fi
fi

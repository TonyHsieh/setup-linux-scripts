#!/usr/bin/env bash
# ==============================================================================
# uninstall-dev-env.sh
# Purpose: Idempotent uninstallation of development environment set up by install-dev-env.sh (including devenv & Nix)
# Target: CachyOS / Arch Linux & WSL2-Ubuntu / Debian Linux & macOS
# ==============================================================================
set -euo pipefail

# Detect OS family and WSL status
detect_os() {
  OS_FAMILY="unknown"
  if [ "$(uname)" = "Darwin" ]; then
    OS_FAMILY="macos"
  elif command -v pacman >/dev/null 2>&1; then
    OS_FAMILY="arch"
  elif command -v apt-get >/dev/null 2>&1; then
    OS_FAMILY="debian"
  fi

  IS_WSL=false
  if [ "$OS_FAMILY" != "macos" ] && grep -qsi Microsoft /proc/version; then
    IS_WSL=true
  fi
}

detect_os
echo "==> Detected OS Family: $OS_FAMILY (WSL: $IS_WSL)"

# Function to check if a package is installed via pacman
is_installed_arch() {
  pacman -Qi "$1" >/dev/null 2>&1
}

# Function to restore backup configuration files
restore_file() {
  local dest="$1"
  local name
  name=$(basename "$dest")

  if [ -f "${dest}.bak" ]; then
    echo "==> Restoring backup for $name"
    mv "${dest}.bak" "$dest"
    echo "   ✓ Successfully restored $dest from backup"
  elif [ -f "$dest" ]; then
    if [ "$name" = ".bashrc" ] && [ -f "/etc/skel/.bashrc" ]; then
      echo "==> Restoring default .bashrc from /etc/skel/.bashrc"
      cp "/etc/skel/.bashrc" "$dest"
    else
      echo "==> Removing deployed config file: $dest (no backup found)"
      rm "$dest"
    fi
  else
    echo "   ✓ $name does not exist, nothing to restore"
  fi
}

uninstall_arch_packages() {
  echo "==> Uninstalling Arch packages"

  # List of native pacman packages to uninstall
  local PACKAGES=(
    bottom
    rustup
    zed
    fluxcd
    helm
    kubectl
    docker
    xclip
    wl-clipboard
    bash-completion
    bash
    k9s
    go-yq
    jq
    tmux
    wget
    curl
    starship
    vim
    git
    sops
    age
    neovim
    nodejs
    npm
    ripgrep
    make
  )

  for pkg in "${PACKAGES[@]}"; do
    if is_installed_arch "$pkg"; then
      echo "==> Uninstalling $pkg"
      sudo pacman -R --noconfirm "$pkg" || echo "⚠️ Could not uninstall $pkg (might be required by other packages)"
    fi
  done

  # Font package list to uninstall
  local FONTS=(
    ttf-meslo-nerd
    ttf-jetbrains-mono-nerd
    ttf-firacode-nerd
    ttf-hack-nerd
    ttf-iosevka-nerd
    ttf-cascadia-code-nerd
  )

  for font in "${FONTS[@]}"; do
    if is_installed_arch "$font"; then
      echo "==> Uninstalling Nerd Font $font"
      sudo pacman -R --noconfirm "$font" || true
    fi
  done

  echo "==> Updating font cache"
  fc-cache -f || true

  # Uninstall AUR packages
  if is_installed_arch "blesh-git"; then
    echo "==> Uninstalling blesh-git"
    sudo pacman -R --noconfirm blesh-git || true
  fi
  if is_installed_arch "kind-bin"; then
    echo "==> Uninstalling kind-bin"
    sudo pacman -R --noconfirm kind-bin || true
  fi
}

uninstall_debian_packages() {
  echo "==> Uninstalling Debian/Ubuntu packages"

  # 1. Uninstall bottom
  if command -v btm >/dev/null 2>&1; then
    echo "==> Uninstalling bottom"
    sudo apt-get purge -y bottom || true
  fi

  # 2. Uninstall kind
  if command -v kind >/dev/null 2>&1; then
    echo "==> Uninstalling kind"
    sudo rm -f /usr/local/bin/kind
  fi

  # 3. Uninstall blesh
  if [ -d "$HOME/.local/share/blesh" ]; then
    echo "==> Uninstalling ble.sh"
    rm -rf "$HOME/.local/share/blesh" "$HOME/.local/bin/ble.sh" || true
  fi

  # 4. Uninstall rustup
  if command -v rustup >/dev/null 2>&1; then
    echo "==> Uninstalling rustup"
    rustup self uninstall -y || true
  fi

  # 5. Uninstall Zed
  if [ -f "$HOME/.local/bin/zed" ]; then
    echo "==> Uninstalling Zed editor"
    rm -f "$HOME/.local/bin/zed"
    rm -rf "$HOME/.local/share/zed"
  fi

  # 6. Uninstall flux
  if command -v flux >/dev/null 2>&1; then
    echo "==> Uninstalling flux"
    sudo rm -f /usr/local/bin/flux
  fi

  # 7. Uninstall helm
  if command -v helm >/dev/null 2>&1; then
    echo "==> Uninstalling helm"
    sudo rm -f /usr/local/bin/helm
  fi

  # 8. Uninstall kubectl
  if command -v kubectl >/dev/null 2>&1; then
    echo "==> Uninstalling kubectl"
    sudo rm -f /usr/local/bin/kubectl
  fi

  # 9. Uninstall k9s
  if command -v k9s >/dev/null 2>&1; then
    echo "==> Uninstalling k9s"
    sudo rm -f /usr/local/bin/k9s
  fi

  # 10. Uninstall yq
  if command -v yq >/dev/null 2>&1; then
    echo "==> Uninstalling yq"
    sudo rm -f /usr/local/bin/yq
  fi

  # 11. Uninstall starship
  if command -v starship >/dev/null 2>&1; then
    echo "==> Uninstalling Starship prompt"
    sudo rm -f /usr/local/bin/starship
  fi

  # 12. Uninstall sops
  if [ -f /usr/local/bin/sops ]; then
    echo "==> Uninstalling sops"
    sudo rm -f /usr/local/bin/sops
  fi

  # 12.5. Uninstall Neovim
  if [ -f /usr/local/bin/nvim ]; then
    echo "==> Uninstalling Neovim"
    sudo rm -f /usr/local/bin/nvim
    sudo rm -rf /usr/local/share/nvim
    sudo rm -rf /usr/local/lib/nvim
  fi

  # 13. Uninstall Docker CLI
  if dpkg -s docker-ce-cli >/dev/null 2>&1; then
    echo "==> Uninstalling Docker CLI"
    sudo apt-get purge -y docker-ce-cli || true
    sudo rm -f /etc/apt/keyrings/docker.asc
    sudo rm -f /etc/apt/sources.list.d/docker.list
  fi

  # 14. Uninstall standard packages
  local PACKAGES=(
    gawk
    build-essential
    wl-clipboard
    xclip
    bash-completion
    bash
    jq
    tmux
    wget
    curl
    vim
    git
    age
    nodejs
    npm
    ripgrep
  )
  for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "==> Uninstalling $pkg"
      sudo apt-get remove --purge -y "$pkg" || echo "⚠️ Could not uninstall $pkg"
    fi
  done

  echo "==> Running apt-get autoremove"
  sudo apt-get autoremove -y || true
  sudo apt-get update -y || true
}

uninstall_macos_packages() {
  echo "==> Uninstalling macOS packages"

  # 1. Uninstall kind
  if command -v kind >/dev/null 2>&1; then
    echo "==> Uninstalling kind"
    brew uninstall kind || true
  fi

  # 2. Uninstall ble.sh
  if [ -d "$HOME/.local/share/blesh" ]; then
    echo "==> Uninstalling ble.sh"
    rm -rf "$HOME/.local/share/blesh" "$HOME/.local/bin/ble.sh" || true
  fi

  # 3. Uninstall Nerd Fonts
  local FONTS=(
    font-meslo-lg-nerd-font
    font-jetbrains-mono-nerd-font
    font-fira-code-nerd-font
    font-hack-nerd-font
    font-iosevka-nerd-font
    font-cascadia-code-nerd-font
  )
  for font in "${FONTS[@]}"; do
    if brew list --cask "$font" >/dev/null 2>&1; then
      echo "==> Uninstalling font $font"
      brew uninstall --cask "$font" || true
    fi
  done

  # 4. Uninstall rustup
  if command -v rustup >/dev/null 2>&1; then
    echo "==> Uninstalling rustup"
    rustup self uninstall -y || true
  fi

  # 5. Uninstall Zed
  if brew list --cask zed >/dev/null 2>&1; then
    echo "==> Uninstalling Zed editor"
    brew uninstall --cask zed || true
  fi

  # 6. Uninstall standard Homebrew packages
  local PACKAGES=(
    bottom
    docker
    fluxcd/tap/flux
    helm
    kubernetes-cli
    bash-completion@2
    bash
    k9s
    yq
    jq
    tmux
    wget
    curl
    starship
    vim
    git
    sops
    age
    neovim
    node
    ripgrep
  )
  for pkg in "${PACKAGES[@]}"; do
    local pkg_name="$pkg"
    if [[ "$pkg" == *"/"* ]]; then
      pkg_name="${pkg##*/}"
    fi
    if brew list --formula "$pkg_name" >/dev/null 2>&1; then
      echo "==> Uninstalling $pkg"
      brew uninstall "$pkg" || echo "⚠️ Could not uninstall $pkg"
    fi
  done
}

uninstall_devenv() {
  echo "==> Uninstalling devenv and Nix"

  # 1. Uninstall devenv CLI
  if [ "$OS_FAMILY" = "arch" ] && is_installed_arch "devenv-bin"; then
    echo "==> Uninstalling devenv-bin via pacman"
    sudo pacman -R --noconfirm devenv-bin || true
  elif [ "$OS_FAMILY" = "arch" ] && is_installed_arch "devenv"; then
    echo "==> Uninstalling devenv via pacman"
    sudo pacman -R --noconfirm devenv || true
  elif [ "$OS_FAMILY" = "macos" ] && command -v brew >/dev/null 2>&1 && brew list --formula devenv >/dev/null 2>&1; then
    echo "==> Uninstalling devenv via Homebrew"
    brew uninstall devenv || true
  fi

  if command -v nix >/dev/null 2>&1; then
    nix profile remove devenv >/dev/null 2>&1 || true
  fi

  rm -f "$HOME/.local/bin/devenv"
  sudo rm -f /usr/local/bin/devenv

  # Remove devenv configuration and cache directories
  rm -rf "$HOME/.config/devenv"
  rm -rf "$HOME/.cache/devenv"
  echo "   ✓ devenv CLI and user cache directories removed"

  # 2. Uninstall Nix (if installed)
  if [ -x /nix/nix-installer ]; then
    echo "==> Uninstalling Nix via Determinate nix-installer"
    sudo /nix/nix-installer uninstall --no-confirm || true
  elif [ -d /nix ]; then
    echo "==> Removing Nix directory and service files"
    if command -v systemctl >/dev/null 2>&1; then
      sudo systemctl stop nix-daemon.service nix-daemon.socket 2>/dev/null || true
      sudo systemctl disable nix-daemon.service nix-daemon.socket 2>/dev/null || true
    fi
    sudo rm -rf /nix
    sudo rm -rf /etc/nix
    sudo rm -f /etc/profile.d/nix.sh
    rm -rf "$HOME/.nix-profile" "$HOME/.nix-defexpr" "$HOME/.nix-channels" "$HOME/.config/nix"
    echo "   ✓ Nix installation and state removed"
  else
    echo "   ✓ No Nix installation detected."
  fi
}

# Run the appropriate uninstaller function
if [ "$OS_FAMILY" = "arch" ]; then
  uninstall_arch_packages
elif [ "$OS_FAMILY" = "debian" ]; then
  uninstall_debian_packages
elif [ "$OS_FAMILY" = "macos" ]; then
  uninstall_macos_packages
fi

# Uninstall devenv and Nix
uninstall_devenv

# Clean up docker group membership (Linux only)
if [ "$OS_FAMILY" != "macos" ]; then
  if groups "$USER" | grep -q "\bdocker\b"; then
    echo "==> Removing $USER from docker group"
    sudo gpasswd -d "$USER" docker || true
  fi
fi

# Clean up LazyVim configurations and caches
LAZYVIM_CONFIG_DIR="$HOME/.config/nvim"
if [ -d "$LAZYVIM_CONFIG_DIR" ] || [ -d "$HOME/.local/share/nvim" ] || [ -d "$HOME/.local/state/nvim" ] || [ -d "$HOME/.cache/nvim" ]; then
  echo "==> Uninstalling LazyVim configurations and Neovim caches"
  rm -rf "$LAZYVIM_CONFIG_DIR"
  rm -rf "$HOME/.local/share/nvim"
  rm -rf "$HOME/.local/state/nvim"
  rm -rf "$HOME/.cache/nvim"
  echo "   ✓ Successfully removed LazyVim and all Neovim files"
fi

# Clean up TPM (TMUX Plugin Manager)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  echo "==> Removing TMUX Plugin Manager (TPM)"
  rm -rf "$TPM_DIR"
fi

# Optional SSH Key cleanup (Prompts in interactive sessions)
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY" ]; then
  if [ -t 0 ]; then
    read -rp "Do you want to delete the generated SSH key at $SSH_KEY? (y/N) " confirm_ssh
    if [[ "$confirm_ssh" =~ ^[Yy]$ ]]; then
      echo "==> Removing SSH key files"
      rm -f "$SSH_KEY" "${SSH_KEY}.pub"
    fi
  else
    echo "==> Skipping SSH key deletion (non-interactive session)"
  fi
fi

# Inform user that sops/age keys are preserved
AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
if [ -f "$AGE_KEY_FILE" ]; then
  echo "==> Note: Your age key pair for SOPS at $AGE_KEY_FILE has been preserved."
fi

# Clean up deployed configuration files
restore_file "$HOME/.bashrc"
restore_file "$HOME/.tmux.conf"
restore_file "$HOME/.config/starship.toml"

echo "==> Uninstallation complete!"
echo "👉 Next steps: Restart your terminal or run: exec bash"

#!/usr/bin/env bash
# ==============================================================================
# install-dev-env.sh
# Purpose: Idempotent CLI tool installation for bash + rust + zed + vim + docker
# Target: CachyOS / Arch Linux & WSL2-Ubuntu / Debian Linux
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

if [ "$OS_FAMILY" = "unknown" ]; then
  echo "❌ Error: Unsupported system. This script supports macOS (Homebrew), Arch Linux/CachyOS (pacman), and Debian/Ubuntu (apt)." >&2
  exit 1
fi

# Function to check if a package is installed via pacman
is_installed_arch() {
  pacman -Qi "$1" >/dev/null 2>&1
}

# Install AUR helper package on Arch
install_aur_arch() {
  local pkg="$1"
  local check_cmd="${2:-}"

  # If a command check is provided and it exists, we are done
  if [[ -n "$check_cmd" ]] && command -v "$check_cmd" >/dev/null 2>&1; then
    echo "==> Command '$check_cmd' is already available in PATH."
    return 0
  fi

  # Otherwise check if the package is recorded in pacman DB
  if is_installed_arch "$pkg"; then
    echo "==> AUR package $pkg is already installed."
    return 0
  fi

  if command -v paru >/dev/null 2>&1; then
    echo "==> Installing $pkg via paru"
    paru -S --needed --noconfirm "$pkg"
  elif command -v yay >/dev/null 2>&1; then
    echo "==> Installing $pkg via yay"
    yay -S --needed --noconfirm "$pkg"
  else
    echo "❌ Error: Neither paru nor yay found. Cannot install AUR package $pkg." >&2
    echo "Please install an AUR helper (paru or yay) first." >&2
    return 1
  fi
}

install_arch_packages() {
  echo "==> Updating package databases"
  sudo pacman -Sy --noconfirm

  # List of native pacman packages to install
  local PACKAGES=(
    git
    vim
    starship
    curl
    wget
    tmux
    jq
    go-yq
    k9s
    bash
    bash-completion
    wl-clipboard
    xclip
    docker
    kubectl
    helm
    fluxcd
    zed
    rustup
    bottom
    sops
    age
    neovim
    nodejs
    npm
    ripgrep
    make
  )

  local TO_INSTALL=()
  for pkg in "${PACKAGES[@]}"; do
    if ! is_installed_arch "$pkg"; then
      TO_INSTALL+=("$pkg")
    fi
  done

  if [ ${#TO_INSTALL[@]} -ne 0 ]; then
    echo "==> Installing packages: ${TO_INSTALL[*]}"
    sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}"
  else
    echo "==> All standard packages are already installed."
  fi

  # Font package list (Nerd Fonts available in standard Arch extra/ repos)
  local FONTS=(
    ttf-meslo-nerd
    ttf-jetbrains-mono-nerd
    ttf-firacode-nerd
    ttf-hack-nerd
    ttf-iosevka-nerd
    ttf-cascadia-code-nerd
  )

  local TO_INSTALL_FONTS=()
  for font in "${FONTS[@]}"; do
    if ! is_installed_arch "$font"; then
      TO_INSTALL_FONTS+=("$font")
    fi
  done

  if [ ${#TO_INSTALL_FONTS[@]} -ne 0 ]; then
    echo "==> Installing Nerd Fonts: ${TO_INSTALL_FONTS[*]}"
    sudo pacman -S --needed --noconfirm "${TO_INSTALL_FONTS[@]}"
    echo "==> Updating font cache"
    fc-cache -f
  else
    echo "==> All requested Nerd Fonts are already installed."
  fi

  echo "==> Checking AUR packages"
  install_aur_arch "blesh-git"
  install_aur_arch "kind-bin" "kind"
}

install_debian_packages() {
  echo "==> Updating apt databases"
  sudo apt-get update -y

  # 1. Install standard packages available in apt
  local PACKAGES=(
    git
    vim
    curl
    wget
    tmux
    jq
    bash
    bash-completion
    xclip
    wl-clipboard
    build-essential
    gawk
    age
    nodejs
    npm
    ripgrep
  )

  local TO_INSTALL=()
  for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      TO_INSTALL+=("$pkg")
    fi
  done

  if [ ${#TO_INSTALL[@]} -ne 0 ]; then
    echo "==> Installing apt packages: ${TO_INSTALL[*]}"
    sudo apt-get install -y "${TO_INSTALL[@]}"
  else
    echo "==> All standard apt packages are already installed."
  fi

  # 1.5. Install Neovim stable binary (since apt versions are often too old for LunarVim)
  if ! command -v nvim >/dev/null 2>&1 || [[ "$(nvim --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" < "0.9.0" ]]; then
    echo "==> Installing/updating Neovim (stable binary)"
    local ARCH
    ARCH=$(uname -m)
    local NVIM_TAR
    if [ "$ARCH" = "x86_64" ]; then
      NVIM_TAR="nvim-linux-x86_64.tar.gz"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
      NVIM_TAR="nvim-linux-arm64.tar.gz"
    else
      echo "❌ Error: Unsupported architecture ($ARCH) for Neovim download." >&2
      return 1
    fi
    curl -LO "https://github.com/neovim/neovim/releases/download/stable/$NVIM_TAR"
    sudo tar -C /usr/local --strip-components 1 -xzf "$NVIM_TAR"
    rm -f "$NVIM_TAR"
  else
    echo "==> Neovim is already installed and meets version requirement."
  fi

  # 2. Install Docker Client CLI (docker-ce-cli)
  if ! command -v docker >/dev/null 2>&1; then
    echo "==> Installing Docker CLI"
    sudo apt-get install -y ca-certificates
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce-cli
  else
    echo "==> Docker is already installed (command 'docker' exists)."
  fi

  # 3. Install starship
  if ! command -v starship >/dev/null 2>&1; then
    echo "==> Installing Starship prompt"
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
  else
    echo "==> Starship is already installed."
  fi

  # 4. Install yq
  if ! command -v yq >/dev/null 2>&1; then
    echo "==> Installing yq"
    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
  else
    echo "==> yq is already installed."
  fi

  # 5. Install k9s
  if ! command -v k9s >/dev/null 2>&1; then
    echo "==> Installing k9s"
    local K9S_VERSION
    K9S_VERSION=$(curl -s "https://api.github.com/repos/derailed/k9s/releases/latest" | jq -r .tag_name)
    curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz -C /tmp k9s
    sudo mv /tmp/k9s /usr/local/bin/k9s
    sudo chmod +x /usr/local/bin/k9s
  else
    echo "==> k9s is already installed."
  fi

  # 6. Install kubectl
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "==> Installing kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
  else
    echo "==> kubectl is already installed."
  fi

  # 7. Install helm
  if ! command -v helm >/dev/null 2>&1; then
    echo "==> Installing helm"
    curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 /tmp/get_helm.sh
    /tmp/get_helm.sh
    rm -f /tmp/get_helm.sh
  else
    echo "==> helm is already installed."
  fi

  # 8. Install flux
  if ! command -v flux >/dev/null 2>&1; then
    echo "==> Installing flux"
    curl -s https://fluxcd.io/install.sh | sudo bash
  else
    echo "==> flux is already installed."
  fi

  # 9. Install Zed
  if ! command -v zed >/dev/null 2>&1; then
    echo "==> Installing Zed editor"
    curl -f https://zed.dev/install.sh | sh
  else
    echo "==> Zed editor is already installed."
  fi

  # 10. Install rustup
  if ! command -v rustup >/dev/null 2>&1; then
    echo "==> Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  else
    echo "==> rustup is already installed."
  fi

  # 11. Install blesh
  local BLESH_DIR="$HOME/.local/share/blesh"
  if [ ! -d "$BLESH_DIR" ] && [ ! -r "$HOME/.local/share/blesh/ble.sh" ]; then
    echo "==> Installing ble.sh (Bash Line Editor)"
    local BLESH_TMP
    BLESH_TMP=$(mktemp -d /tmp/ble.sh.XXXXXX)
    git clone --recursive --depth 1 https://github.com/akinomyoga/ble.sh.git "$BLESH_TMP"
    make -C "$BLESH_TMP" install PREFIX="$HOME/.local"
    rm -rf "$BLESH_TMP"
  else
    echo "==> ble.sh is already installed."
  fi

  # 12. Install kind
  if ! command -v kind >/dev/null 2>&1; then
    echo "==> Installing kind"
    local KIND_VERSION
    KIND_VERSION=$(curl -s "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest" | jq -r .tag_name)
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
  else
    echo "==> kind is already installed."
  fi

  # 13. Install bottom
  if ! command -v btm >/dev/null 2>&1; then
    echo "==> Installing bottom"
    local BTM_VERSION
    BTM_VERSION=$(curl -s "https://api.github.com/repos/ClementTsang/bottom/releases/latest" | jq -r .tag_name)
    local ARCH
    ARCH=$(dpkg --print-architecture)
    curl -Lo /tmp/bottom.deb "https://github.com/ClementTsang/bottom/releases/download/${BTM_VERSION}/bottom_${BTM_VERSION}-1_${ARCH}.deb"
    sudo apt-get install -y /tmp/bottom.deb
    rm -f /tmp/bottom.deb
  else
    echo "==> bottom is already installed."
  fi

  # 14. Install sops
  if ! command -v sops >/dev/null 2>&1; then
    echo "==> Installing sops"
    local SOPS_VER
    SOPS_VER=$(curl -s "https://api.github.com/repos/getsops/sops/releases/latest" | grep -oP '"tag_name": "\K[^"]+')
    curl -LO "https://github.com/getsops/sops/releases/download/${SOPS_VER}/sops-${SOPS_VER}.linux.amd64"
    sudo mv sops-*.linux.amd64 /usr/local/bin/sops
    sudo chmod +x /usr/local/bin/sops
  else
    echo "==> sops is already installed."
  fi
}

install_macos_packages() {
  # 1. Ensure Homebrew is installed
  if ! command -v brew >/dev/null 2>&1; then
    echo "==> Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Configure brew path for current session depending on architecture (Intel / Apple Silicon)
    if [ -f "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    echo "==> Homebrew is already installed."
  fi

  # Standard packages
  local PACKAGES=(
    git
    vim
    starship
    curl
    wget
    tmux
    jq
    yq
    k9s
    bash
    bash-completion@2
    kubernetes-cli
    helm
    fluxcd/tap/flux
    docker
    bottom
    sops
    age
    neovim
    node
    ripgrep
    gawk
  )

  local TO_INSTALL=()
  for pkg in "${PACKAGES[@]}"; do
    local pkg_name="$pkg"
    if [[ "$pkg" == *"/"* ]]; then
      pkg_name="${pkg##*/}"
    fi
    if ! brew list --formula "$pkg_name" >/dev/null 2>&1; then
      TO_INSTALL+=("$pkg")
    fi
  done

  if [ ${#TO_INSTALL[@]} -ne 0 ]; then
    echo "==> Installing Homebrew packages: ${TO_INSTALL[*]}"
    brew install "${TO_INSTALL[@]}"
  else
    echo "==> All standard Homebrew packages are already installed."
  fi

  # GUI Casks
  if ! command -v zed >/dev/null 2>&1 && ! brew list --cask zed >/dev/null 2>&1; then
    echo "==> Installing Zed editor"
    brew install --cask zed
  fi

  # 3. Install rustup
  if ! command -v rustup >/dev/null 2>&1; then
    echo "==> Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  else
    echo "==> rustup is already installed."
  fi

  # 4. Nerd Fonts
  local FONTS=(
    font-meslo-lg-nerd-font
    font-jetbrains-mono-nerd-font
    font-fira-code-nerd-font
    font-hack-nerd-font
    font-iosevka-nerd-font
    font-cascadia-code-nf
  )
  local TO_INSTALL_FONTS=()
  for font in "${FONTS[@]}"; do
    if ! brew list --cask "$font" >/dev/null 2>&1; then
      TO_INSTALL_FONTS+=("$font")
    fi
  done

  if [ ${#TO_INSTALL_FONTS[@]} -ne 0 ]; then
    echo "==> Installing Nerd Fonts via Homebrew: ${TO_INSTALL_FONTS[*]}"
    for font in "${TO_INSTALL_FONTS[@]}"; do
      if brew install --cask "$font"; then
        echo "==> Installed cask: $font"
      else
        echo "⚠️ Warning: Failed to install cask '$font'. Continuing with remaining fonts."
      fi
    done
  else
    echo "==> All requested Nerd Fonts are already installed."
  fi

  # 5. Install ble.sh (Bash Line Editor)
  local BLESH_DIR="$HOME/.local/share/blesh"
  if [ ! -d "$BLESH_DIR" ] && [ ! -r "$HOME/.local/share/blesh/ble.sh" ]; then
    echo "==> Installing ble.sh (Bash Line Editor)"
    local BLESH_TMP
    BLESH_TMP=$(mktemp -d /tmp/ble.sh.XXXXXX)
    git clone --recursive --depth 1 https://github.com/akinomyoga/ble.sh.git "$BLESH_TMP"
    make -C "$BLESH_TMP" install PREFIX="$HOME/.local"
    rm -rf "$BLESH_TMP"
  else
    echo "==> ble.sh is already installed."
  fi

  # 6. Install kind
  if ! command -v kind >/dev/null 2>&1; then
    echo "==> Installing kind"
    brew install kind
  else
    echo "==> kind is already installed."
  fi
}

# Run the appropriate installer function
if [ "$OS_FAMILY" = "arch" ]; then
  install_arch_packages
elif [ "$OS_FAMILY" = "debian" ]; then
  install_debian_packages
elif [ "$OS_FAMILY" = "macos" ]; then
  install_macos_packages
fi

# Enable Docker daemon service (Native Arch Linux only)
if [ "$OS_FAMILY" = "arch" ]; then
  if ! systemctl is-active --quiet docker; then
    echo "==> Enabling and starting Docker daemon"
    sudo systemctl enable --now docker.service
  else
    echo "==> Docker service is already active."
  fi
elif [ "$OS_FAMILY" = "macos" ]; then
  echo "==> Skipping Docker daemon service configuration (assuming Docker Desktop is managed via application on macOS)."
else
  echo "==> Skipping Docker daemon service configuration (assuming Docker Desktop integration on WSL)."
fi

# Add current user to docker group if not already a member
if [ "$OS_FAMILY" != "macos" ]; then
  if [ "$OS_FAMILY" = "debian" ] && ! getent group docker >/dev/null; then
    sudo groupadd docker
  fi

  if ! groups "$USER" | grep -q "\bdocker\b"; then
    echo "==> Adding $USER to docker group"
    sudo usermod -aG docker "$USER"
    echo "⚠️ Note: You will need to log out and back in (or run 'newgrp docker') for docker group membership to apply."
  else
    echo "==> User $USER is already in docker group."
  fi
fi

# Initialize Rust toolchain via rustup if no active toolchain is set
export PATH="$HOME/.cargo/bin:$PATH"
if ! rustup show active-toolchain >/dev/null 2>&1; then
  echo "==> Initializing stable Rust toolchain via rustup"
  rustup default stable
else
  echo "==> Rust toolchain is already active."
fi

# Enable Rust components
echo "==> Adding rustfmt and clippy components"
rustup component add rustfmt clippy || true

# Setup TMUX Plugin Manager (TPM) if missing
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  echo "==> Installing TMUX Plugin Manager (TPM)"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  echo "==> TMUX Plugin Manager (TPM) is already installed."
fi

# Generate SSH key if no private key exists in ~/.ssh
SSH_KEY="$HOME/.ssh/id_ed25519"
HAS_SSH_KEY=false
if [ -d "$HOME/.ssh" ] && find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' ! -name '*.pub' | grep -q .; then
  HAS_SSH_KEY=true
fi

if [ "$HAS_SSH_KEY" = false ]; then
  echo "==> Generating SSH key"
  if [ -t 0 ]; then
    read -rp "Enter your email address for the SSH key [your_email@example.com]: " ssh_email
  else
    ssh_email=""
  fi
  if [ -z "$ssh_email" ]; then
    ssh_email="your_email@example.com"
  fi
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$ssh_email" -f "$SSH_KEY"

  echo "==> SSH key generated successfully!"
  echo "👉 Instructions to add this key to GitHub:"
  echo "   1. Copy the public key to your clipboard:"
  if [ "$IS_WSL" = true ]; then
    if command -v clip.exe >/dev/null 2>&1; then
      clip.exe < "${SSH_KEY}.pub"
      echo "      (Automatically copied to Windows clipboard using clip.exe!)"
    elif [ -f "/mnt/c/Windows/System32/clip.exe" ]; then
      /mnt/c/Windows/System32/clip.exe < "${SSH_KEY}.pub"
      echo "      (Automatically copied to Windows clipboard using clip.exe!)"
    else
      echo "      Run: cat ${SSH_KEY}.pub"
    fi
  elif command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "${SSH_KEY}.pub"
    echo "      (Automatically copied to clipboard using pbcopy!)"
    echo "      Alternatively, run: cat ${SSH_KEY}.pub"
  elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy < "${SSH_KEY}.pub"
    echo "      (Automatically copied to clipboard using wl-copy!)"
    echo "      Alternatively, run: cat ${SSH_KEY}.pub"
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard < "${SSH_KEY}.pub"
    echo "      (Automatically copied to clipboard using xclip!)"
    echo "      Alternatively, run: cat ${SSH_KEY}.pub"
  else
    echo "      Run: cat ${SSH_KEY}.pub"
  fi
  echo "   2. Go to GitHub SSH settings: https://github.com/settings/keys"
  echo "   3. Click 'New SSH key', choose a title, paste the key, and click 'Add SSH key'."
  if [ "$OS_FAMILY" = "macos" ]; then
    echo "   4. (Optional) To automatically load the passphrase into your SSH agent and macOS Keychain, add this to ~/.ssh/config:"
    echo "      Host github.com"
    echo "        AddKeysToAgent yes"
    echo "        UseKeychain yes"
    echo "        IdentityFile ~/.ssh/id_ed25519"
  else
    echo "   4. (Optional) To automatically load the passphrase into your SSH agent, add this to ~/.ssh/config:"
    echo "      Host github.com"
    echo "        AddKeysToAgent yes"
    echo "        IdentityFile ~/.ssh/id_ed25519"
  fi
  echo ""
else
  echo "==> Existing SSH key files detected. Skipping SSH key generation."
  find "$HOME/.ssh" -maxdepth 1 -type f -name 'id_*' | sort | while IFS= read -r key_file; do
    echo "   - $key_file"
  done
fi

# Setup age key pair for SOPS if missing
AGE_KEY_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"
if [ ! -f "$AGE_KEY_FILE" ]; then
  if command -v age-keygen >/dev/null 2>&1; then
    echo "==> Generating age key pair for SOPS"
    mkdir -p "$AGE_KEY_DIR"
    chmod 700 "$AGE_KEY_DIR"
    age-keygen -o "$AGE_KEY_FILE"
    chmod 600 "$AGE_KEY_FILE"
    echo "==> age key pair generated successfully!"
    echo "👉 Your public key is:"
    grep "public key:" "$AGE_KEY_FILE"
  else
    echo "⚠️ Warning: age-keygen command not found, cannot generate age key pair."
  fi
else
  echo "==> age key pair already exists at $AGE_KEY_FILE"
  echo "👉 Your public key is:"
  grep "public key:" "$AGE_KEY_FILE"
fi

# Setup LunarVim if missing
LVIM_BIN="$HOME/.local/bin/lvim"
if [ ! -f "$LVIM_BIN" ]; then
  echo "==> Installing LunarVim"
  # Run the official installer non-interactively using the --yes flag
  LV_BRANCH='master' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/master/utils/installer/install.sh) --yes
else
  echo "==> LunarVim is already installed."
fi

# Deploy configurations
deploy_file() {
  local src="$1"
  local dest="$2"
  local name
  name=$(basename "$dest")

  if [ -f "$dest" ]; then
    if cmp -s "$src" "$dest"; then
      echo "   ✓ $dest is already up-to-date (no changes needed)"
      return 0
    fi
    echo "   ⚠️ Found existing $dest. Creating backup at ${dest}.bak"
    cp "$dest" "${dest}.bak"
  fi
  cp "$src" "$dest"
  echo "   ✓ Successfully deployed $name to $dest"
}

echo "==> Deploying shell and tmux configurations"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
deploy_file "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
deploy_file "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"

if [ -f "$SCRIPT_DIR/setup-starship.sh" ]; then
  echo "==> Deploying Starship configuration"
  bash "$SCRIPT_DIR/setup-starship.sh"
fi

echo "==> Setup and installation complete!"
echo "👉 Next steps:"
if [ "$IS_WSL" = true ]; then
  echo "   1. Setup Nerd Fonts on Windows (Host):"
  echo "      - Download a Nerd Font from: https://www.nerdfonts.com/font-downloads (e.g. JetBrainsMono, FiraCode, Meslo)"
  echo "      - Open the ZIP file, double-click the font file (.ttf/.otf), and click 'Install'."
  echo "      - In Windows Terminal, open Settings (Ctrl+,) -> Ubuntu profile -> Appearance -> Font Face, and select your font."
else
  echo "   1. Set your terminal font to one of the installed Nerd Fonts (e.g., 'MesloLGS Nerd Font' or 'JetBrainsMono Nerd Font')"
fi
echo "   2. Restart your terminal or run: exec bash"
echo "   3. Add your SSH key to GitHub if you haven't already (see details above or go to https://github.com/settings/keys)"

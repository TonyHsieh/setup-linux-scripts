# Developer Environment Setup Scripts for Linux, WSL & macOS

This repository contains clean, idempotent, and highly portable developer environment configuration scripts. It supports native **macOS** (via Homebrew), **CachyOS / Arch Linux** (via pacman), and **WSL2-Ubuntu / Debian Linux** (via apt).

---

## 📂 File Structure

* **`install-dev-env.sh`**: The main setup script. Automatically detects your OS (macOS, Arch Linux, Debian/Ubuntu), installs CLI tools (`rustup`, `docker`, `kubectl`, `helm`, `flux`, `k9s`, `yq`, `starship`, `ble.sh`), configures your environments, and deploys configuration files.
* **`setup-starship.sh`**: Installs/deploys the Starship prompt profile configuration.
* **`starship.toml`**: Custom Starship configuration theme (includes time, directory context, git branch status, node/java info).
* **`.bashrc`**: Custom portable bash configuration.
* **`.tmux.conf`**: Configures tmux, enabling vi-mode copy-paste, scroll-back buffers, and TPM (Tmux Plugin Manager) plugins.

---

## 🚀 Getting Started

Simply run the installation script:
```bash
./install-dev-env.sh
```

---

## 💾 Manual Backup Instructions

Before you run the script, it is highly recommended to manually preserve your existing shell and terminal configs in a dedicated backup folder. 

Run this snippet in your current terminal:
```bash
# Create a backup folder in your home directory
mkdir -p ~/setup_backup

# Backup your current configuration files (only if they exist)
cp ~/.bashrc ~/setup_backup/.bashrc
[ -f ~/.tmux.conf ] && cp ~/.tmux.conf ~/setup_backup/.tmux.conf
[ -f ~/.config/starship.toml ] && cp ~/.config/starship.toml ~/setup_backup/starship.toml
```

---

## 🔄 Rollback Instructions

If you run the installer and decide you want to return to your previous shell configurations:

```bash
# Restore your original configuration files
cp ~/setup_backup/.bashrc ~/.bashrc
[ -f ~/setup_backup/.tmux.conf ] && cp ~/setup_backup/.tmux.conf ~/.tmux.conf || rm -f ~/.tmux.conf
[ -f ~/setup_backup/starship.toml ] && cp ~/setup_backup/starship.toml ~/.config/starship.toml || rm -f ~/.config/starship.toml

# Reload your shell
exec bash
```

---

## 🛠️ Customizing with `.bashrc.local`

The main `.bashrc` file is tracked in this repository and is kept general/portable so it can be updated easily. 

To keep your own system-specific paths, private API keys, or custom aliases, you **should not edit `.bashrc` directly**. Instead, use the **`~/.bashrc.local`** file.

The deployed `.bashrc` contains this hook at the very bottom:
```bash
[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local
```

### How to use it:
Create `~/.bashrc.local` if it does not exist, and write any local configuration there:
```bash
touch ~/.bashrc.local
```

### Examples of what should go in `~/.bashrc.local`:
* **Work or machine-specific environment variables:**
  ```bash
  export WORK_API_KEY="super-secret-token"
  export DEPLOY_ENV="production"
  ```
* **Custom PATH extensions (e.g. custom tools):**
  ```bash
  export PATH="$HOME/.my-custom-tools/bin:$PATH"
  ```
* **Personal Aliases:**
  ```bash
  alias deploy-prod='echo "deploying..." && helm upgrade ...'
  alias myip='curl ifconfig.me'
  ```

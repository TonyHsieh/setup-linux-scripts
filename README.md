# Developer Environment Setup Scripts for Linux, WSL & macOS

This repository contains clean, idempotent, and highly portable developer environment configuration scripts. It supports native **macOS** (via Homebrew), **CachyOS / Arch Linux** (via pacman), and **WSL2-Ubuntu / Debian Linux** (via apt).

---

## 📂 File Structure

* **`install-dev-env.sh`**: The main setup script. Automatically detects your OS (macOS, Arch Linux, Debian/Ubuntu), installs CLI tools (`rustup`, `docker`, `kubectl`, `helm`, `flux`, `k9s`, `yq`, `starship`, `ble.sh`, `bottom`), configures your environments, and deploys configuration files.
* **`uninstall-dev-env.sh`**: The uninstallation script. Reverts all configurations, restores backed-up files, and uninstalls all tools that were installed.
* **`setup-starship.sh`**: Installs/deploys the Starship prompt profile configuration.
* **`starship.toml`**: Custom Starship configuration theme. See the [Starship TOML Feature Guide](docs/starship-toml.md) for configuration details.
* **`.bashrc`**: Custom portable bash configuration (integrates [Starship](docs/starship.md) and [ble.sh](docs/blesh.md)).
* **`.tmux.conf`**: Configures tmux, enabling vi-mode copy-paste, scroll-back buffers, and TPM (Tmux Plugin Manager) plugins. See the [TMUX Feature Guide](docs/tmux.md) for configuration details.

---

## 📖 Feature & Tool Guides

Detailed feature lists and configuration details for the core shell enhancements are available in the following guides:

* **[Starship TOML Features](docs/starship-toml.md)**: Details on background colors, custom language detectors, and status symbols configured in `starship.toml`.
* **[Starship Prompt Overview](docs/starship.md)**: Information on cross-shell capabilities, performance, and shell integration.
* **[ble.sh (Bash Line Editor) Features](docs/blesh.md)**: Guide to syntax highlighting, auto-suggestions, and interactive completion in Bash.
* **[TMUX Configuration Features](docs/tmux.md)**: Guide to Vi-mode copy/paste, portable clipboard integration, Vim-like navigation, and automatic session resurrection.

---

## 🚀 Getting Started

Simply run the installation script:
```bash
./install-dev-env.sh
```

> [!NOTE]
> The installation script is safe and idempotent. It checks if configuration files (like `~/.bashrc` and `~/.tmux.conf`) are different before backing up and replacing them. If no changes are detected, your existing configuration is left untouched.

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

## 🔄 Rollback & Uninstallation Instructions

You can automatically revert all changes (including package installations, font settings, configurations, and TPM) by running:

```bash
./uninstall-dev-env.sh
```

> [!IMPORTANT]
> Because `ble.sh` (which runs background processes) and `starship` (which renders the command prompt) are actively running in your current terminal session, deleting their files will cause your current shell to print "No such file or directory" errors as it attempts to execute the deleted files.
>
> **This is expected and the script has successfully completed.** To stop the errors and reload a clean environment, simply run:
> ```bash
> exec bash
> ```
> (or close your terminal window and open a new one).

Alternatively, if you prefer to manually restore your backup configuration files:

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

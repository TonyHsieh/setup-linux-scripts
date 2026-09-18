# Developer Environment Setup Scripts for Linux, WSL & macOS

This repository contains clean, idempotent, and highly portable developer environment configuration scripts. It supports native **macOS** (via Homebrew), **CachyOS / Arch Linux** (via pacman), and **WSL2-Ubuntu / Debian Linux** (via apt).

---

## 📂 File Structure

* **`install-dev-env.sh`**: **Tier 1 Base Setup Script**. Automatically detects your OS (macOS, Arch Linux, Debian/Ubuntu), installs CLI & AI tools (`rustup`, `docker`, `kubectl`, `helm`, `flux`, `k9s`, `yq`, `starship`, `ble.sh`, `bottom`, `sops`, `age`, `neovim`, `LazyVim`, `opencode`, `hermes`), configures shell profiles, and deploys configurations.
* **`install-local-services.sh`**: **Tier 2 Local Services & Container Mesh Script**. Provisions Podman (rootless), Traefik v3 ingress, `mkcert` (local SSL for `*.localhost`), `justfile` task runner, BentoPDF UI, local Postgres, and containerized MCP servers.
* **`uninstall-dev-env.sh`**: Reverts Tier 1 base configurations, restores backed-up files, and uninstalls CLI tools (preserving user credentials).
* **`uninstall-local-services.sh`**: Teardown script for Tier 2 local services, stopping Podman container stacks, Traefik proxy, and removing local service aliases.
* **`remove-lunarvim.sh`**: Cleanup utility script. Completely removes legacy LunarVim binaries (`lvim`) and clears Neovim configuration/state directories (`~/.config/nvim`, `~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`) to prepare for a fresh LazyVim installation.
* **`setup-starship.sh`**: Installs/deploys the Starship prompt profile configuration.
* **`starship.toml`**: Custom Starship configuration theme. See the [Starship TOML Feature Guide](docs/starship-toml.md) for configuration details.
* **`.bashrc`**: Custom portable bash configuration (integrates [Starship](docs/starship.md) and [ble.sh](docs/blesh.md) with performance tunings).
* **`.tmux.conf`**: Configures tmux, enabling vi-mode copy-paste, scroll-back buffers, and TPM (Tmux Plugin Manager) plugins. See the [TMUX Feature Guide](docs/tmux.md) for configuration details.

---

## ⚡ Vim / Neovim Environment

> [!IMPORTANT]
> **We are no longer using LunarVim.** The development environment now standardizes on **Neovim (v0.9+ Stable)** paired with the **[LazyVim](https://www.lazyvim.org/)** framework.

### 🧹 Upgrading / Removing Legacy LunarVim
If your machine previously used LunarVim, run the removal script before running `install-dev-env.sh`:

```bash
./remove-lunarvim.sh
```

This script cleans up:
* The `lvim` binary (`~/.local/bin/lvim`)
* LunarVim directories (`~/.local/share/lunarvim`, `~/.cache/lvim`, `~/.config/lvim`)
* Existing Neovim config and state directories (`~/.config/nvim`, `~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`) to avoid configuration collisions.

### 🛠️ Current Vim Setup & Documentation
* **Vim Engine**: **Neovim v0.9+** (Installed via official stable appimage / release binaries or system package manager).
* **Distribution**: [**LazyVim Starter**](https://github.com/LazyVim/starter) (Modular, fast, batteries-included Neovim setup).
* **Documentation & Usage Guide**: See the detailed **[LazyVim Primer for Vim Users](docs/lazyvim-primer.md)** for essential shortcuts, buffer controls, LSP management (`:LazyExtras`), and plugin customization.

---

## 🤖 AI Agents & Coding Assistants

The setup script automatically equips your environment with modern terminal AI agents:

* **[OpenCode](https://opencode.ai/)** (`opencode` / alias `oc`): Open-source, model-agnostic terminal AI coding agent.
* **[Hermes Agent](https://nousresearch.com/)** (`hermes` / alias `ha`): Autonomous, self-improving AI agent developed by Nous Research.

### Configuration & API Keys
Configure your provider API keys in your `~/.bashrc.local` file:
```bash
export OPENAI_API_KEY="your-api-key"
export ANTHROPIC_API_KEY="your-api-key"
```
Or run the Hermes onboarding setup directly:
```bash
hermes setup --portal
```

---

## 📖 Feature & Tool Guides

Detailed feature lists and configuration details for the core shell enhancements are available in the following guides:

* **[Local Services & Container Mesh Guide](docs/local-services-guide.md)**: Architecture, Podman setup, Traefik v3 ingress, `mkcert` SSL, `jl` task runner, BentoPDF UI, and container workflows.
* **[OpenCode & Hermes Agent Setup Guide](docs/opencode-hermes-guide.md)**: Setup, sample tasks, complementary scopes, and MCP tool configuration for OpenCode and Hermes Agent.
* **[LazyVim Primer for Vim Users](docs/lazyvim-primer.md)**: Jumpstart guide covering LazyVim shortcuts, buffers, LSPs, and configuration.
* **[Secret Management with SOPS & age](docs/SOPS-AGE-Guide.md)**: Guide on generating keys, configuring `.sops.yaml`, and managing encrypted repository secrets.
* **[Starship TOML Features](docs/starship-toml.md)**: Details on background colors, custom language detectors, and status symbols configured in `starship.toml`.
* **[Starship Prompt Overview](docs/starship.md)**: Information on cross-shell capabilities, performance, and shell integration.
* **[ble.sh (Bash Line Editor) Features](docs/blesh.md)**: Guide to syntax highlighting, auto-suggestions, interactive completion, and anti-hang performance configurations in Bash.
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

---

## 📌 Appendix: Idempotency & Re-Execution Guarantees

Both installation scripts (`install-dev-env.sh` and `install-local-services.sh`) are **100% idempotent**. They can be re-executed safely at any time (e.g. after pulling repository updates) without causing duplicate package installs, configuration corruption, duplicate alias appends, or service downtime.

### 🛠️ `install-dev-env.sh` (Tier 1 Base Setup)
* **Package Management**: Inspects package manager DBs (`pacman -Qi`, `dpkg -s`, `brew list`) and command availability before attempting installation. Skips already-installed packages.
* **CLI Tools (`opencode`, `hermes`, `kubectl`, `helm`, `sops`)**: Guarded by `command -v <tool>` checks. If a binary exists, downloading is skipped.
* **Configurations (`.bashrc`, `.tmux.conf`)**: Uses `cmp -s` file comparison. If deployed files match repository sources, no changes are made.
* **SSH & Encryption Keys**: Inspects `~/.ssh/` and `~/.config/sops/age/keys.txt`. Never overwrites existing keys.
* **Environment Hooks**: Uses `grep -q` checks before appending stubs to `~/.bashrc.local`, avoiding duplicate entries.

### 🌐 `install-local-services.sh` (Tier 2 Container Mesh)
* **Rootless Podman Socket**: Enables user-level systemd sockets (`podman.socket`) idempotently.
* **SSL Certificates (`mkcert`)**: Checks if `~/.local/share/local-services/certs/` contains valid wildcard SSL certificates before running `mkcert`.
* **Task Runner Alias (`jl`)**: Inspects `~/.bashrc` to ensure the alias is only appended once.
* **Container Stack Management**: `podman-compose up -d` is container-idempotent; running services with matching configurations remain active without restart or downtime.

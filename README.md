# Developer Environment Setup Scripts for Linux, WSL & macOS

This repository contains clean, idempotent, and highly portable developer environment configuration scripts organized into a modular **two-tier architecture**. It supports native **macOS** (via Homebrew), **CachyOS / Arch Linux** (via pacman/AUR), and **WSL2-Ubuntu / Debian Linux** (via apt).

---

## 🏛️ Architecture Overview

The repository is structured into two complementary tiers:

* **Tier 1 — Base Developer Environment (`install-dev-env.sh`)**:
  Bootstraps core CLI tools, system compilers, Neovim paired with [LazyVim](https://www.lazyvim.org/), Nix-powered [Devenv](https://devenv.sh/), terminal AI agents ([OpenCode](https://opencode.ai/) & [Hermes Agent](https://nousresearch.com/)), [Starship](https://starship.rs/) prompt, [ble.sh](https://github.com/akinomyoga/ble.sh) line editor, [TMUX](https://github.com/tmux/tmux) with [TPM](https://github.com/tmux-plugins/tpm), [SOPS](https://github.com/getsops/sops) & [age](https://github.com/FiloSottile/age) secret encryption, and SSH key management.
* **Tier 2 — Local Services & Container Mesh (`install-local-services.sh`)**:
  Provisions a local container mesh using rootless [Podman](https://podman.io/), [Traefik v3](https://traefik.io/) ingress reverse proxy, [mkcert](https://github.com/FiloSottile/mkcert) for locally trusted `*.localhost` SSL/TLS, containerized [Puppeteer MCP](https://modelcontextprotocol.io/) server, [BentoPDF](https://github.com/alam00000/bentopdf) web UI, local PostgreSQL, and a [justfile](https://github.com/casey/just) task runner aliased as `jl`.

---

## 📂 File & Directory Structure

* **[`install-dev-env.sh`](install-dev-env.sh)**: **Tier 1 Base Setup Script**. Automatically detects OS (macOS, Arch/CachyOS, Debian/Ubuntu), installs CLI & AI tools (`rustup`, `docker`, `kubectl`, `helm`, `flux`, `k9s`, `yq`, `starship`, `ble.sh`, `bottom`, `sops`, `age`, `neovim`, `LazyVim`, `devenv`, `opencode`, `hermes`), configures shell profiles, and deploys configurations.
* **[`install-local-services.sh`](install-local-services.sh)**: **Tier 2 Local Services & Container Mesh Script**. Provisions rootless Podman, Traefik v3 ingress proxy, `mkcert` wildcard SSL for `*.localhost`, BentoPDF UI, local PostgreSQL, containerized Puppeteer MCP server, and `justfile` task runner (`jl` alias).
* **[`uninstall-dev-env.sh`](uninstall-dev-env.sh)**: **Tier 1 Teardown Script**. Reverts Tier 1 base configurations, uninstalls CLI tools, removes Nix/devenv, cleans up Neovim/LazyVim, restores backed-up files, and preserves user encryption keys.
* **[`uninstall-local-services.sh`](uninstall-local-services.sh)**: **Tier 2 Teardown Script**. Stops Podman container stacks, tears down Traefik reverse proxy, cleans up the `jl` alias, and optionally removes local service configurations.
* **[`remove-lunarvim.sh`](remove-lunarvim.sh)**: **Cleanup Utility Script**. Completely removes legacy LunarVim binaries (`lvim`) and clears Neovim configuration/state directories (`~/.config/nvim`, `~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`) to prepare for a fresh LazyVim installation.
* **[`setup-starship.sh`](setup-starship.sh)**: Installs/deploys the Starship prompt profile configuration idempotently.
* **[`starship.toml`](starship.toml)**: Custom Starship configuration theme. See the [Starship TOML Feature Guide](docs/starship-toml.md) for configuration details.
* **[`.bashrc`](.bashrc)**: Custom portable bash configuration (integrates [Starship](docs/starship.md) and [ble.sh](docs/blesh.md) with performance tunings, Nix/devenv integration, and AI agent aliases).
* **[`.tmux.conf`](.tmux.conf)**: Configures tmux, enabling vi-mode copy-paste, cross-platform clipboard (Wayland, X11, macOS, WSL), scroll-back buffers, and TPM plugins. See the [TMUX Feature Guide](docs/tmux.md) for configuration details.
* **[`next-feature-plan.md`](next-feature-plan.md)**: Architectural roadmap and implementation plan for AI agent model providers (Gemini, OpenRouter, Groq) and local lightweight LLM services.
* **[`docs/`](docs/)**: Comprehensive documentation and feature guides for all integrated tools and workflows.

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
* **Vim Engine**: **Neovim v0.9+** (Installed via official stable binary or system package manager).
* **Distribution**: [**LazyVim Starter**](https://github.com/LazyVim/starter) (Modular, fast, batteries-included Neovim setup).
* **Documentation & Usage Guide**: See the detailed **[LazyVim Primer for Vim Users](docs/lazyvim-primer.md)** for essential shortcuts, buffer controls, LSP management (`:LazyExtras`), and plugin customization.

---

## 🛠️ Declarative Environments with Devenv & Nix

The environment includes first-class support for **[Devenv](https://devenv.sh/)** and **[Nix](https://nixos.org/)**, enabling declarative, reproducible, per-project developer environments without container overhead.

* **Automated Installation**: Devenv and the Determinate Nix installer are provisioned during `install-dev-env.sh`.
* **Conflict Prevention**: Built-in environment checks detect active Conda/Mamba environments and warn of `PATH` or `LD_LIBRARY_PATH` symbol conflicts.
* **Performance Tuning**: `ble.sh` is automatically configured to ignore Nix store directories (`/nix/store/*`) to prevent shell autocomplete latency.
* **Guide**: See **[Devenv Best Practices & Guide](docs/devenv.md)** for `devenv.nix` configuration patterns, process management (`devenv up`), and container generation.

---

## 🤖 AI Agents & Coding Assistants

The setup script automatically equips your environment with modern terminal AI agents:

* **[OpenCode](https://opencode.ai/)** (`opencode` / alias `oc`): Open-source, model-agnostic terminal AI coding agent for repository pair programming.
* **[Hermes Agent](https://nousresearch.com/)** (`hermes` / alias `ha`): Autonomous, self-improving AI agent developed by Nous Research for system operations and automated research.

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

### Model Context Protocol (MCP) Integration
Both agents are preconfigured with MCP tools:
* **OpenCode** (`~/.config/opencode/opencode.json`): Preconfigured with filesystem, git, postgres, and Puppeteer browser agents.
* **Hermes Agent** (`~/.hermes/config.yaml`): Preconfigured with Puppeteer, fetch, and GitHub MCP tools.
* **Detailed Guide**: See **[OpenCode & Hermes Agent Setup Guide](docs/opencode-hermes-guide.md)**.
* **Roadmap**: See **[Feature Plan: AI Agent Providers & Local LLMs](next-feature-plan.md)** for planned Gemini, OpenRouter, Groq, and local Ollama integrations.

---

## 🌐 Local Services & Container Mesh (Tier 2)

Running `./install-local-services.sh` establishes an isolated, rootless container service mesh that makes local development tools accessible via clean, SSL-secured domain names without port numbers.

### Available Local Web Services

| Service | Local Domain / URL | Description |
| :--- | :--- | :--- |
| **BentoPDF UI** | `https://pdf.localhost` | Privacy-first local PDF manipulation toolkit |
| **Traefik Dashboard** | `http://traefik.localhost:8088` | Traefik v3 ingress proxy & router metrics |
| **Puppeteer MCP** | `http://puppeteer.mcp.localhost` | Containerized headless browser MCP server |
| **PostgreSQL DB** | `localhost:5432` | Local dev database (`devuser` / `devpassword` / `devdb`) |

### Task Runner Commands (`jl` Alias)
Manage the local services using the `jl` command (alias for `just -f ~/.local/share/local-services/justfile`):

```bash
jl status    # View status of running container services
jl logs      # Follow real-time service logs (or: jl logs bentopdf)
jl restart   # Restart all container mesh services
jl up        # Start all local container services
jl down      # Stop all local container services
jl update    # Run Podman auto-update on tagged containers
jl certs     # Regenerate local wildcard SSL certificates
jl mcp-info  # Show OpenCode & Hermes MCP connection snippets
```

* **Detailed Guide**: See **[Local Services & Container Mesh Guide](docs/local-services-guide.md)**.

---

## 📖 Feature & Tool Guides

Detailed guides for all integrated tools and workflows are available in the [`docs/`](docs/) directory:

* **[Local Services & Container Mesh Guide](docs/local-services-guide.md)**: Architecture, rootless Podman, Traefik v3 ingress, `mkcert` SSL, `jl` task runner, BentoPDF UI, and container workflows.
* **[OpenCode & Hermes Agent Setup Guide](docs/opencode-hermes-guide.md)**: Setup, sample tasks, complementary scopes, and MCP tool configuration for OpenCode and Hermes Agent.
* **[Devenv Best Practices & Guide](docs/devenv.md)**: Configuring Nix-powered declarative environments (`devenv.nix`), process management (`devenv up`), and mitigating Conda/Nix conflicts.
* **[LazyVim Primer for Vim Users](docs/lazyvim-primer.md)**: Jumpstart guide covering LazyVim shortcuts, buffers, LSPs, and configuration.
* **[Secret Management with SOPS & age](docs/SOPS-AGE-Guide.md)**: Generating keys, configuring `.sops.yaml`, and managing encrypted repository secrets.
* **[Starship TOML Features](docs/starship-toml.md)**: Details on background colors, custom language detectors, and status symbols configured in `starship.toml`.
* **[Starship Prompt Overview](docs/starship.md)**: Information on cross-shell capabilities, performance, and shell integration.
* **[ble.sh (Bash Line Editor) Features](docs/blesh.md)**: Guide to syntax highlighting, auto-suggestions, interactive completion, and anti-hang performance configurations in Bash.
* **[TMUX Configuration Features](docs/tmux.md)**: Vi-mode copy/paste, portable clipboard integration, Vim-like navigation, and automatic session resurrection.
* **[Feature Plan: AI Agent Providers & Local LLMs](next-feature-plan.md)**: Roadmap for Google Gemini, Groq, OpenRouter, and local containerized LLM inference engines.

---

## 🚀 Getting Started

### Step 1: Install Base Developer Environment (Tier 1)
Run the base installation script:
```bash
./install-dev-env.sh
```

After installation completes, reload your shell session:
```bash
exec bash
```

> [!NOTE]
> The installation script is safe and idempotent. It checks if configuration files (like `~/.bashrc` and `~/.tmux.conf`) are different before backing up and replacing them. If no changes are detected, your existing configuration is left untouched.

### Step 2: (Optional) Install Local Services & Container Mesh (Tier 2)
To provision rootless Podman, Traefik v3 ingress, BentoPDF, and containerized MCP servers:
```bash
./install-local-services.sh
```

Reload your shell or source `~/.bashrc` to activate the `jl` alias:
```bash
exec bash
jl status
```

---

## 💾 Manual Backup Instructions

Before you run the setup script, you can manually preserve your existing shell and terminal configs in a dedicated backup folder:

```bash
# Create a backup folder in your home directory
mkdir -p ~/setup_backup

# Backup your current configuration files (only if they exist)
[ -f ~/.bashrc ] && cp ~/.bashrc ~/setup_backup/.bashrc
[ -f ~/.tmux.conf ] && cp ~/.tmux.conf ~/setup_backup/.tmux.conf
[ -f ~/.config/starship.toml ] && cp ~/.config/starship.toml ~/setup_backup/starship.toml
```

---

## 🔄 Rollback & Uninstallation Instructions

### Reverting Tier 2 Local Services
To stop and remove local container services without touching your base developer tools:
```bash
./uninstall-local-services.sh
```

### Reverting Tier 1 Base Environment
To completely revert all base configurations, packages, Nix/devenv, LazyVim, and restore backed-up dotfiles:
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

### Manual Configuration Restore
If you prefer to manually restore your backup configuration files:
```bash
# Restore your original configuration files
[ -f ~/setup_backup/.bashrc ] && cp ~/setup_backup/.bashrc ~/.bashrc
[ -f ~/setup_backup/.tmux.conf ] && cp ~/setup_backup/.tmux.conf ~/.tmux.conf || rm -f ~/.tmux.conf
[ -f ~/setup_backup/starship.toml ] && cp ~/setup_backup/starship.toml ~/.config/starship.toml || rm -f ~/.config/starship.toml

# Reload your shell
exec bash
```

---

## 🛠️ Customizing with `.bashrc.local`

The main `.bashrc` file is tracked in this repository and is kept general/portable so it can be updated easily. 

To keep your own system-specific paths, private API keys, or custom aliases, **do not edit `.bashrc` directly**. Instead, use the **`~/.bashrc.local`** file.

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
* **AI Agent API Keys:**
  ```bash
  export OPENAI_API_KEY="sk-..."
  export ANTHROPIC_API_KEY="sk-ant-..."
  export GEMINI_API_KEY="AIzaSy..."
  ```
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
* **CLI Tools (`opencode`, `hermes`, `kubectl`, `helm`, `sops`, `devenv`)**: Guarded by `command -v <tool>` checks. If a binary exists, downloading is skipped.
* **Configurations (`.bashrc`, `.tmux.conf`)**: Uses `cmp -s` file comparison. If deployed files match repository sources, no changes are made.
* **SSH & Encryption Keys**: Inspects `~/.ssh/` and `~/.config/sops/age/keys.txt`. Never overwrites existing keys.
* **Environment Hooks**: Uses `grep -q` checks before appending stubs to `~/.bashrc.local`, avoiding duplicate entries.

### 🌐 `install-local-services.sh` (Tier 2 Container Mesh)
* **Rootless Podman Socket**: Enables user-level systemd sockets (`podman.socket`) idempotently.
* **SSL Certificates (`mkcert`)**: Checks if `~/.local/share/local-services/certs/` contains valid wildcard SSL certificates before running `mkcert`.
* **Task Runner Alias (`jl`)**: Inspects `~/.bashrc` to ensure the alias is only appended once.
* **Container Stack Management**: `podman-compose up -d` is container-idempotent; running services with matching configurations remain active without restart or downtime.

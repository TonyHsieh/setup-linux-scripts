# 🤖 AGENTS.md — Repository Operating Constitution & Ground Rules

This document establishes the mandatory architectural rules, constraints, and operating standards for all autonomous AI coding agents (**Google Antigravity**, **OpenCode**, **Claude Code**, **Hermes Agent**, **GitHub Copilot**, and **Cursor**) operating within this repository.

Every AI agent reading this workspace must adhere to these directives unconditionally.

---

## 🏛️ The Six Prime Directives

### 1. The 90/10 Nix-to-Native Host Split
* **The 10% Native Host (Tier 0 — NEVER Nix This)**:
  * Kernel, firmware, hardware WiFi, and power management.
  * GPU drivers (WSL2 `/usr/lib/wsl/lib` paravirtualized shims, host NVIDIA CUDA, AMD ROCm) and display/KDE Wayland.
  * Container engine runtime (rootless Podman daemon & systemd user socket).
  * Host network daemons: Tailscale (`/dev/net/tun`), sysctl unprivileged port binding (`80/443` for Traefik).
  * Security roots: `mkcert` root CA trust store, host SSH private keys, and SOPS `keys.txt` (paths referenced, never committed into `/nix/store`).
  * Heavy GPU appliance: Local Ollama container service.
  * macOS GUI applications: Homebrew Casks.
* **The 90% Declarative User-Space (Tier 1 — Always Nix This)**:
  * All CLI tools, editors (Neovim), shells (Bash + ble.sh + Starship), multiplexers (Tmux), and dotfiles.
  * The complete AI Agent Suite (`opencode`, `hermes-agent`, `claude-code`, `antigravity-cli`, `herdr`, `github-copilot-cli`).

### 2. Never Install Global Compilers (Tier 3 Devenv Rule)
* **PROHIBITED**: Never install language compilers (`rustc`, `go`, `node`, `python`, `javac`, `gcc`) into global `home.packages` or via global package managers.
* All compilers, runtimes, linters, pre-commit hooks, and mock services live strictly per-project inside hermetic `devenv.nix` / `flake.nix` environments activated via `direnv` or `devenv shell`.

### 3. The Unified AI Agent Lane (`numtide/llm-agents.nix`)
* All AI agent CLIs are managed declaratively via `numtide/llm-agents.nix` and `nixpkgs`.
* **CRITICAL GOTCHA**: **NEVER set `llm-agents.inputs.nixpkgs.follows = "nixpkgs"`**. Overriding `follows` invalidates the `cache.numtide.com` pre-built binary cache, forcing hours of local compilation of heavy Rust/Python packages (`herdr`, `hermes-agent`).
* **Keep Base Nixpkgs Pinned**: The base `nixpkgs` input remains pinned to its stable baseline (October 10, 2026). AI tools update independently via `nix flake update llm-agents` (or `jl update-agents`).
* **Disable In-App Auto-Updaters**: In-app self-updaters (`claude update`, `opencode update`) will fail because `/nix/store` is immutable. Updates are performed through Nix Flakes.
* **State vs. Config**: Nix manages declarative config templates; active state and auth tokens (`~/.claude/`, `~/.hermes/`, `~/.local/share/opencode`, `~/.config/herdr/`) remain writable on the host. Secrets stay strictly out of `/nix/store`.

### 4. The Geoffrey Huntley Sandbox Pattern (`ghuntley/nix-demo`)
* **An overlay is a tool guardrail definition, not a sandbox boundary.**
* **Three-Layer Sandbox Architecture**:
  * **Layer 1 (Toolset Guardrail)**: Source-patched `agentGit` blocking `--force`, `-f`, `+refspec`, and `--delete`. Must pin `gitMinimal = prev.gitMinimal;` to avoid rebuilding the entire world.
  * **Layer 2 (Project Agent Shell)**: `templates/agent-sandbox` devenv environment with isolated Git worktrees and stripped credentials (`SSH_AUTH_SOCK = ""`, `SOPS_AGE_KEY_FILE = "/dev/null"`), supervised by Herdr.
  * **Layer 3 (True System Boundary)**: Rootless Podman container built via `dockerTools.buildLayeredImage` mounting only the project directory, with no host network for untrusted tasks.
* **Non-NixOS Host Reality**: No `sudo` for agents on WSL2, CachyOS, or macOS (no instant rootfs rollback).

### 5. MCP Server Boundaries (Containers vs. Nix Derivations)
* **Puppeteer / Playwright / Databases ARE Container Workloads**: Heavy browser runtimes with complex C++ dependencies run as ephemeral Podman containers (`docker.io/mcp/puppeteer:latest`).
* **Filesystem / Git MCP Tools ARE Nix Derivations**: Local tools run as fast, offline, cryptographically pinned Nix binaries in `/nix/store`, completely eliminating slow and insecure `npx -y` downloads.

### 6. Terminal Multiplexer Harmony (Tmux vs. Herdr)
* **Tmux Prefix**: `Ctrl-b` (Outer developer workbench).
* **Herdr Prefix**: `Ctrl-a` (Inner agent supervisor & attention queue).
* Seeded via `dotfiles/herdr/config.toml` to prevent cross-machine collisions between WSL2 and CachyOS.

---

## 🚫 Strictly Prohibited Actions for Agents

When generating code, proposing fixes, or running shell commands in this repository, agents must **NEVER**:
1. ❌ Suggest or execute `npm install -g`, `pip install`, `cargo install`, `go install`, or `sudo pacman/apt install` for developer tooling.
2. ❌ Add `inputs.nixpkgs.follows` to `llm-agents` in `flake.nix`.
3. ❌ Hardcode API keys, tokens, or age secret keys into any `.nix`, `.json`, `.toml`, or `.yaml` file tracked by Git.
4. ❌ Force-push to any git branch (`git push -f`, `git push --force`).
5. ❌ Attempt to modify files inside `/nix/store` directly.
6. ❌ Break or overwrite user state directories (`~/.claude/`, `~/.hermes/`, `~/.local/share/opencode`) by symlinking them to the read-only Nix store.

---

## 🗓️ Temporary Patches & Dated Reminder Registry

When applying temporary hotfixes or vendored patches (following the Geoffrey Huntley pattern), record them here with a target expiration date to be reviewed and removed once merged upstream:

| Patch File | Upstream Component | Date Added | Target Removal Date | Upstream Issue / Tracking |
| :--- | :--- | :--- | :--- | :--- |
| `third_party/git/0001-forbid-force-push.patch` | Git `builtin/push.c` | 2026-11-13 | Permanent (Policy) | Organizational guardrail (ghuntley/nix-demo) |
| `home/ai-agents.nix` (`hermesAgentPatched`) | `numtide/llm-agents.nix` `hermes-agent` | 2026-11-25 | 2027-01-15 | Bare `sys.executable -m hermes_cli.kanban_worker_client` lacks `.hermes-wrapped` `site.addsitedir` deps on `PYTHONPATH` |

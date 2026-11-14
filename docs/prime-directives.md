# 🏛️ Architectural Prime Directives: The 90/10 Declarative Manifesto

This document establishes the permanent architectural foundation for this repository. It defines the operational boundaries between **Native Host Services**, **Declarative Nix Environments**, **Containerized Workloads**, and **Agent Sandboxing**.

---

## 🧒 1. "Explain It Like I'm 13": The Kitchen Analogy

Imagine your computer is a high-end commercial restaurant kitchen.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 THE DEVELOPER RESTAURANT                               │
│                                                                                        │
│   🛠️ NIX (The Chef's Precision Tool Belt)        📦 CONTAINERS (The Dedicated Appliance)│
│   • Runs directly in your hands (Host OS)        • Sealed metal box in the corner       │
│   • Reaches everywhere (CWD, worktrees, pipes)   • Plugs into the wall (Network Port)   │
│   • Exact mathematical recipe (Store hash)       • Bundles own plumbing, water, power   │
│   • Examples: git, ripgrep, neovim, oc, agy      • Examples: Ollama, PostgreSQL, Plex   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

1. **Nix is the Chef's Tool Belt**:
   * Every knife, spoon, and spatula is forged with mathematical precision (`/nix/store/...`).
   * When you pull out a tool (like `git`, `ripgrep`, or `opencode`), it sits directly in your hands. It runs instantly (0ms latency), touches your cutting board (`$PWD`), and pipes output to other tools.
   * No two knives can dull each other or conflict over which version of steel (`glibc`) they require.

2. **Containers are the Commercial Appliances**:
   * A container (Podman / Docker) is an electric pizza oven or ice cream machine bolted in the corner.
   * It has its own sealed metal casing, private power, and internal plumbing.
   * You don't use it like a knife; you speak to it through an order window (a **network port** like `http://localhost:11434` or `http://localhost:5432`).
   * It cannot touch your kitchen counter unless you explicitly cut a slot into the box (`-v /my/project:/workspace`).

---

## 🏛️ 2. The 90/10 Architecture Split

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 THE 90/10 ARCHITECTURE                                 │
│                                                                                        │
│   TIER 0: Thin Native Host (10% — NEVER Nix This)                                      │
│   ├── Kernel, GPU drivers (WSL2 /usr/lib/wsl/lib, NVIDIA CUDA, AMD ROCm), Display/KDE │
│   ├── Container Engine (Podman rootless daemon), Tailscale daemon, sysctl port 80/443  │
│   ├── mkcert root CA trust store, Hardware WiFi & Power management                     │
│   └── Host Secrets (SSH keys, SOPS age keys on disk — paths referenced, never stored)  │
│                                                                                        │
│   TIER 1: Declarative User Profile (Home Manager via Flakes)                           │
│   ├── CLI Toolchain: git, neovim, tmux, starship, btop, ripgrep, jq, yq, sops, age    │
│   ├── AI Agent Suite: opencode, hermes-agent, claude-code, herdr, agy, copilot-cli     │
│   └── Configs as Code: starship.toml, tmux.conf, herdr/config.toml, environment.d      │
│                                                                                        │
│   TIER 2: Local Container Mesh (Podman Compose)                                        │
│   └── Heavy/Multi-tier appliances: Ollama (GPU-accelerated), Traefik, PostgreSQL, Plex │
│                                                                                        │
│   TIER 3: Per-Project Ephemeral Environments (Devenv / Flakes — NEVER Global)          │
│   ├── Language compilers: Rust, Go, Node.js, Python, Java/Scala, WASM                 │
│   └── Agent Sandboxes: Patched Git guardrails, pinned MCP servers, isolated worktrees │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### The 10% Native Host (Tier 0 — NEVER Nix This)
* **Kernel & Hardware**: Linux kernel, device firmware, WiFi, and power profiles.
* **GPU Subsystems**: 
  * In WSL2: The `/usr/lib/wsl/lib` paravirtualized DirectX kernel shims (`/dev/dxg`, `libcuda.so.1`).
  * In Bare Metal (CachyOS): Host NVIDIA CUDA / AMD ROCm driver packages.
* **Privileged Daemons**: Tailscale (requires `/dev/net/tun` and root network namespace) and rootless Podman user socket (`podman.socket`).
* **Kernel Sysctl**: Unprivileged port binding (`net.ipv4.ip_unprivileged_port_start=80`).
* **Cryptographic Roots**: Host SSH keys (`~/.ssh/id_ed25519`), SOPS age key (`~/.config/sops/age/keys.txt`), and `mkcert` Local Root CA. Secrets remain on disk; Nix references paths, never values.
* **GPU Appliance**: Ollama container service running with host GPU acceleration.

### The 90% Declarative User-Space (Tier 1 — Always Nix This)
* All interactive CLI developer tools, line editors, shells, terminal multiplexers, and dotfiles.
* Running via Nix provides **zero-overhead native execution** while guaranteeing bit-for-bit parity across WSL2, CachyOS, and macOS.

---

## 🚫 3. The Golden Rule: Never Install Global Compilers (Tier 3)

* **Rule**: Never install language compilers (`rustc`, `go`, `node`, `python`, `javac`, `gcc`) in `home.packages` or via global package managers (`npm -g`, `pip`).
* **Why**: Global compilers cause project dependency drift, version collisions, and non-reproducible builds.
* **Implementation**: Every project defines its exact compiler versions and linters inside a local `devenv.nix` / `flake.nix` environment, activated automatically via `direnv`.

---

## 🤖 4. The Unified AI Agent Lane (`numtide/llm-agents.nix`)

All autonomous coding agents (**OpenCode**, **Hermes Agent**, **Claude Code**, **Google Antigravity CLI**, **Herdr**, and **Copilot CLI**) are consolidated into Declarative Nix:

1. **The Critical Binary Cache Gotcha**:
   * **Directive**: **NEVER set `llm-agents.inputs.nixpkgs.follows = "nixpkgs"`**.
   * **Reason**: `numtide/llm-agents.nix` builds packages against its own pinned `nixpkgs-unstable`. Overriding `follows` invalidates the `cache.numtide.com` binary cache, forcing your laptop to locally compile massive Rust packages (`herdr`) and Python/C++ toolchains (`hermes-agent`).
2. **Independent Update Cadence**:
   * Keep base `nixpkgs` pinned to its tested baseline (October 10, 2026).
   * Update AI tools independently and surgically via:
     ```bash
     jl update-agents
     # executes: nix flake lock --update-input llm-agents && home-manager switch --flake .
     ```
3. **Immutability vs. In-App Updaters**:
   * Commands like `claude update` or `opencode update` fail because `/nix/store` is strictly read-only. In-app updaters are disabled; all upgrades flow through Flake locks.
4. **State vs. Config Separation**:
   * Declarative configurations are linked by Home Manager (`dotfiles/herdr/config.toml`, `dotfiles/opencode/opencode.json`).
   * Active authentication cookies, chat histories, and SQLite state files (`~/.claude/`, `~/.hermes/`, `~/.local/share/opencode`) remain on the host filesystem and are never symlinked to `/nix/store`.

---

## 🛡️ 5. The Geoffrey Huntley Sandbox Pattern (`ghuntley/nix-demo`)

From Geoffrey Huntley's [*Patch the Planet*](https://ghuntley.com/patch/), we adopt the principle that **an overlay is a tool guardrail definition, not a sandbox boundary**.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              THREE-LAYER AGENT SANDBOX                                 │
│                                                                                        │
│   LAYER 1: Toolset Guardrails (Nix Overlay)                                            │
│   • Source-level Git patch: rejects `--force`, `-f`, `+refspec`, and `--delete`        │
│   • gitMinimal PIN: Leaves build-time git unpatched to prevent a world rebuild         │
│   • Pinned MCP servers: Replaces dynamic unpinned `npx -y` with fixed derivations      │
│                                                                                        │
│   LAYER 2: Project Agent Shell (Devenv: templates/agent-sandbox)                       │
│   • Isolated Git Worktree: Agent operates only in `.worktrees/<branch>`               │
│   • Stripped Credentials: $SSH_AUTH_SOCK and $SOPS_AGE_KEY_FILE masked to /dev/null   │
│   • Herdr Supervision: `hc` manages attention queue and user approvals                │
│                                                                                        │
│   LAYER 3: True System Boundary (Rootless Podman OCI Container)                        │
│   • Built with Nix `dockerTools.buildLayeredImage` (zero drift)                        │
│   • Read-write mount ONLY for target project worktree; home directory masked in tmpfs  │
│   • Loopback networking to local Ollama (11434); no external internet for untrusted run│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

* **No Sudo for Agents**: On non-NixOS hosts (WSL2, CachyOS, macOS), agents are never granted `sudo` permissions because there is no instant btrfs/NixOS rootfs rollback to recover from rogue system destruction.

---

## 🦙 6. Why Ollama is a Container (Debunking the "Time Horizon" Myth)

Ollama runs as a Tier 2 rootless Podman container, **not** because of execution time horizon (systemd services in Nix run indefinitely), but because:
1. **It is an Appliance**: Ollama is a headless HTTP API daemon (`localhost:11434`), shared concurrently across multiple agents and web interfaces.
2. **GPU Driver Isolation**: Packaging C++ tensor libraries, CUDA runtimes, and ROCm blobs inside a vendor-supported container image (`docker.io/ollama/ollama:latest`) eliminates local driver compilation hell.
3. **Mesh Accessibility**: Running as a container service behind Traefik and Tailscale allows secondary devices (iPhone, secondary laptops) to access GPU inference without duplicating model weights.

---

## 🔌 7. MCP Server Boundaries: Containers vs. Nix Derivations

* **Heavy / Browser Tools ARE Podman Containers**:
  * Tools like **Puppeteer / Playwright** require a full headless Chromium browser with complex C++ rendering engines and display shims. Running them via `podman run -i --rm docker.io/mcp/puppeteer:latest` traps malicious web scripts inside a disposable container.
* **Local Tooling ARE Nix Derivations**:
  * Local filesystem and Git MCP servers must be packaged as **Nix derivations**, replacing slow, unpinned, and insecure `npx -y` downloads with instant, offline, cryptographically verified local binaries.

---

## 🪟 8. Terminal Multiplexer Harmony (Tmux vs. Herdr)

To prevent nested keystroke capture collisions:
* **Tmux** uses prefix **`Ctrl-b`** (Outer developer workbench).
* **Herdr** uses prefix **`Ctrl-a`** (Inner agent supervisor & attention queue).
* Enforced via [`dotfiles/herdr/config.toml`](../dotfiles/herdr/config.toml) across all deployments.

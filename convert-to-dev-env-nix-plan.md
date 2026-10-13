# ❄️ Architecture & Implementation Plan: Convert to Declarative Nix & Devenv

**Target System**: Cross-Platform (Ubuntu / Debian, WSL2, CachyOS / Arch Linux, NixOS, macOS Darwin)  
**Core Tooling**: Nix Flakes, Home Manager, Devenv, direnv, Rootless Podman  
**Document Status**: Final Architectural Plan  

---

## 🎯 1. Executive Summary & Modernization Goals

This plan outlines the strategic migration of `TonyHsieh/setup-linux-scripts` from imperative shell scripts (`install-dev-env.sh` and `install-local-services.sh`) to a **declarative, reproducible, and cross-platform Nix Flakes architecture**.

### Core Problem with Procedural Shell Scripts
* **Package Manager Fragmentation**: Divergent logic across `apt`, `pacman`, `yay`/`paru`, and Homebrew leads to version mismatches (e.g. outdated Neovim in Ubuntu apt requiring custom tarball extraction, manual GitHub release downloads for `k9s`, `sops`, and `yq`).
* **Non-Atomic Upgrades & Fragile Uninstalls**: Shell scripts mutate global system directories (`/usr/local/bin`, `/etc/apt/keyrings`). Rollbacks are complex and error-prone.
* **Imperative Dotfile Management**: Backing up and copying `.bashrc` and `.tmux.conf` via `cp`/`cmp` requires custom drift detection and backup maintenance (`.bak`).

### The Modern Nix Architecture Vision
By combining **Nix Flakes**, **Home Manager**, and **Devenv**, we establish a clean, multi-layered environment:
1. **Tier 0 (Host Bootstrap)**: Minimal one-line bootstrap providing Determinate Nix and basic prerequisites.
2. **Tier 1 (User Environment via Home Manager)**: Declarative CLI packages, shell (`programs.bash`), prompt (`programs.starship`), multiplexer (`programs.tmux`), AI agent configurations, and dotfiles across Linux and macOS.
3. **Tier 2 (Local Container Mesh)**: Rootless container orchestration (Podman + Traefik v3 + mkcert + local Postgres) managed via systemd user services or task runners.
4. **Tier 3 (Project Toolchains via Devenv)**: Isolated, per-repository language compilers (Rust, Node.js, Python), project-specific services, and pre-commit hooks, eliminating global compiler pollution.

---

## 🏛️ 2. Architectural Layering: What Belongs Where?

A common failure mode when adopting Nix is attempting to force every host system task into Nix expressions. The table below delineates the boundaries between **Nix Home Manager**, **Project Devenv Flakes**, and the **Host Operating System**:

```mermaid
flowchart TD
    subgraph Host["Tier 0: Host Operating System & Privileged Daemons"]
        H1["Determinate Nix Installer"]
        H2["Rootless Podman / Docker Socket"]
        H3["Unprivileged Port sysctl (80/443)"]
        H4["One-time Key Gen (SSH ed25519, SOPS age key)"]
        H5["mkcert Root CA System Trust Registration"]
    end

    subgraph User["Tier 1: Global User Environment (Nix Flakes + Home Manager)"]
        U1["Universal CLI Tools (git, jq, yq, ripgrep, btm, k9s, sops)"]
        U2["Shell Environment (Bash, ble.sh, aliases, starship prompt)"]
        U3["Terminal Multiplexer (tmux + declarative plugins)"]
        U4["Editor Setup (Neovim / LazyVim symlink)"]
        U5["direnv + nix-direnv (Instant project shell activation)"]
        U6["AI Agent Configs (OpenCode, Hermes, AGY skills)"]
        U7["Platform Modules (WSL clipboard/Wayland, macOS Keychain)"]
    end

    subgraph Project["Tier 3: Project Workspaces (devenv.nix + Common Flake Module)"]
        P1["Language Compilers (Rust toolchain, Node.js, Python venv, Go)"]
        P2["Project Background Services (Project DB, Redis, Mock APIs)"]
        P3["Git Pre-commit Hooks (treefmt, nixpkgs-fmt, clippy, linters)"]
        P4["Project Task Scripts (scripts.build, scripts.test)"]
        P5["Project Environment Variables (DATABASE_URL, PORT)"]
    end

    Host --> User
    User --> Project
```

### Detailed Component Classification Matrix

| Component / Tool | Current Script Implementation | Target Tier | Target Nix / Tool Mechanism | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Nix & Flakes Engine** | Determinate Nix curl script | Tier 0 (Host) | Determinate Nix Installer | Must be installed on the host with system daemon permissions. |
| **CLI Utilities** (`git`, `jq`, `yq`, `ripgrep`, `bottom`, `sops`, `age`, `k9s`, `kubectl`, `helm`, `fluxcd`, `kind`, `just`, `mkcert`, `fzf`) | `apt` / `pacman` / `brew` / GitHub releases | Tier 1 (Home Manager) | `home.packages = with pkgs; [ ... ]` | Uniform versions across Ubuntu, Arch, and macOS; atomic updates. |
| **Bash Shell & ble.sh** | Managed `.bashrc` + cloned `ble.sh` | Tier 1 (Home Manager) | `programs.bash` + `blesh` package | Managed declaratively; preserves custom autocomplete/anti-hang options. |
| **Starship Prompt** | `setup-starship.sh` + `starship.toml` | Tier 1 (Home Manager) | `programs.starship` + `xdg.configFile."starship.toml"` | Home Manager natively supports Starship config and shell integration. |
| **TMUX & Plugins** | `.tmux.conf` + cloned TPM repository | Tier 1 (Home Manager) | `programs.tmux` + `tmuxPlugins.*` | Eliminates manual git cloning of TPM; plugins are locked via Nixpkgs. |
| **Neovim & LazyVim** | Binary tarball / package + cloned LazyVim starter | Tier 1 (Home Manager) | `programs.neovim` + `xdg.configFile."nvim"` symlink | Nix installs Neovim 0.10+; user configuration remains modular. |
| **Direnv & nix-direnv** | Not present | Tier 1 (Home Manager) | `programs.direnv = { enable = true; nix-direnv.enable = true; }` | Automatically loads `devenv` when entering project directories. |
| **AI Agents & MCP** (`opencode`, `hermes`) | Upstream curl scripts + JSON configs | Tier 1 (Home Manager) | `home.file` configs + wrapper packages | Declarative JSON/YAML deployment; predictable MCP endpoints. |
| **Language Compilers** (`rustc`, `cargo`, `nodejs`, `python`) | Global install via `rustup`, `apt`, `pacman` | **Tier 3 (Project devenv)** | `languages.*.enable = true` in `devenv.nix` | **Never install global compilers.** Prevents multi-project version clashes. |
| **Local Container Mesh** (Traefik v3, BentoPDF, Puppeteer MCP, Postgres) | Podman compose script (`install-local-services.sh`) | Tier 2 (Local Services) | User systemd units or rootless Podman Compose | Needs host container runtime and network port bindings (80/443). |
| **Keys & Secrets Generation** | `ssh-keygen`, `age-keygen` | Tier 0 (Host Bootstrap) | One-time bootstrap script (outside Nix store) | Private keys must remain secure on host; only paths are declared in Nix. |
| **WSL Integrations** (clip.exe, Wayland socket, OneDrive links) | Procedural bash conditionals in `.bashrc` | Tier 1 (Home Manager) | Conditional `home/wsl.nix` module | Cleanly activated only on `system == "x86_64-linux"` when WSL is detected. |

---

## 🧩 3. Common Standards for All Dev-Env Nix Flakes

To prevent configuration drift across repositories, what should be **common and shared by all project-level dev-env flakes**?

The modernized architecture establishes a reusable **Common Devenv Module** (`modules/devenv-common.nix`) and a **Flake Project Template** (`templates/devenv-starter/`).

```mermaid
flowchart LR
    A["TonyHsieh/setup-linux-scripts (Root Flake)"] -->|"Exports"| B["devenvModules.common"]
    A -->|"Exports"| C["templates.default (devenv-starter)"]

    D["Project A (Rust Backend)"] -->|"Imports common module"| B
    E["Project B (Node.js Frontend)"] -->|"Imports common module"| B
    F["Project C (Python AI Agent)"] -->|"Imports common module"| B

    B --> G["Shared Utilities: git, jq, ripgrep, sops, just"]
    B --> H["Binary Cache: devenv.cachix.org"]
    B --> I["Common Pre-commit: nixpkgs-fmt, whitespace, secret leaks"]
    B --> J["Environment Hygiene: Conda guard, SSL/Artifactory stubs"]
```

### 1. Shared Nixpkgs & Binary Cache (Cachix)
Every dev-env flake must configure standard binary substitutes to avoid compiling packages locally:
* **Substituters**: `https://cache.nixos.org` and `https://devenv.cachix.org`
* **Trusted Public Keys**: `devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=`
* This ensures that entering any project workspace takes seconds instead of compiling toolchains.

### 2. Universal Developer Baseline CLI
Every project shell inherits a baseline suite of utilities required for common operations:
* **VCS**: `pkgs.git`, `pkgs.git-lfs`
* **Data Processing**: `pkgs.jq`, `pkgs.yq-go`, `pkgs.ripgrep`, `pkgs.fd`
* **Task Automation**: `pkgs.just`
* **Secrets**: `pkgs.sops`, `pkgs.age`

### 3. Unified Git Pre-Commit Quality Standards
Every dev-env flake imports consistent Git pre-commit hooks:
* `treefmt.enable = true` (or `nixpkgs-fmt.enable = true`)
* `pre-commit.hooks.trailing-whitespace-fixer.enable = true`
* `pre-commit.hooks.end-of-file-fixer.enable = true`
* `pre-commit.hooks.check-yaml.enable = true`
* `pre-commit.hooks.check-json.enable = true`
* `pre-commit.hooks.detect-private-keys.enable = true`

### 4. Shell Hygiene & Environment Guards
* **Conda/Mamba Isolation Guard**: An automatic `enterShell` hook that detects active Conda environments (`$CONDA_PREFIX`) and warns or unsets conflicting variables (`LD_LIBRARY_PATH`, `PYTHONPATH`).
* **Corporate CA / SSL Auto-Detection**: Standardized export of `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` if corporate security certificates or Artifactory credentials are required.
* **Informative Banner**: A clean, uniform startup banner showing active project name, toolchain versions, and available `just` recipes.

### 5. Local Service Mesh Integration
* Environment hooks that provide default service endpoints pointing to the Tier 2 local mesh:
  * `MCP_PUPPETEER_URL = "http://puppeteer.mcp.localhost/sse"`
  * `DATABASE_DEV_URL = "postgres://devuser:devpassword@localhost:5432/devdb"`

---

## 📁 4. Target Repository Structure

The modernized repository replaces procedural monolithic scripts with a modular Nix Flake and Home Manager architecture:

```
setup-linux-scripts/
├── flake.nix                       # Multi-platform entry point (homeConfigurations & devenvModules)
├── flake.lock                      # Locked dependency graph
│
├── bootstrap/                      # Minimal host bootstrap scripts
│   ├── install-nix.sh              # Idempotent Determinate Nix installer
│   └── bootstrap-home.sh           # Activates Home Manager configuration for current user/OS
│
├── home/                           # Home Manager Configuration Modules
│   ├── default.nix                 # Core entry point importing submodules
│   ├── packages.nix                # Cross-platform CLI utilities (git, jq, yq, k9s, etc.)
│   ├── shell.nix                   # Bash shell configuration, ble.sh, history, aliases
│   ├── tmux.nix                    # TMUX configuration and declarative plugins
│   ├── starship.nix                # Starship prompt configuration
│   ├── git.nix                     # Git global configuration & ignores
│   ├── neovim.nix                  # Neovim & LazyVim config deployment
│   ├── ai-agents.nix               # OpenCode & Hermes configs, agy skill, MCP definitions
│   ├── wsl.nix                     # WSL2 specific adjustments (clipboard, Wayland, OneDrive)
│   └── darwin.nix                  # macOS specific adjustments (Homebrew paths, Keychain)
│
├── modules/                        # Reusable Flake & Devenv Modules
│   └── devenv-common.nix           # Common Devenv module shared by all project flakes
│
├── templates/                      # Flake templates for initializing new projects
│   └── devenv-starter/             # Starter template (flake.nix + devenv.nix + .envrc)
│       ├── .envrc
│       ├── devenv.nix
│       └── flake.nix
│
├── local-services/                 # Tier 2 Local Container Mesh
│   ├── docker-compose.yml          # Traefik v3 + BentoPDF + Puppeteer MCP + Postgres
│   ├── justfile                    # Local service task runner (jl)
│   └── traefik/
│       └── dynamic.yml             # Local wildcard SSL routing (*.localhost)
│
├── dotfiles/                       # Static or templated configuration sources
│   ├── starship.toml               # Custom Starship prompt theme
│   └── nvim/                       # LazyVim user configurations (lua/plugins, etc.)
│
├── docs/                           # Documentation and guides
└── README.md                       # Comprehensive repository documentation
```

---

## 🛠️ 5. Implementation Blueprint & Module Specifications

### 5.1 Root `flake.nix` (Multi-Platform Entry Point)

The `flake.nix` provides Home Manager configurations for Linux (`x86_64-linux`), macOS (`aarch64-darwin`), and exports the reusable `devenvModules.common` module:

```nix
{
  description = "Cross-Platform Declarative Developer Environment & Devenv Ecosystem";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, home-manager, devenv, systems, ... }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      # 1. Export Reusable Devenv Module for all project repositories
      devenvModules.common = import ./modules/devenv-common.nix;

      # 2. Project Flake Templates
      templates = {
        default = {
          path = ./templates/devenv-starter;
          description = "Standard devenv project starter with common linting and toolchains";
        };
      };

      # 3. User Home Manager Configurations for your specific environments
      homeConfigurations = {
        # 1. WSL2 Ubuntu (User: tonyh, Home: /home/tonyh)
        "wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          extraSpecialArgs = { inherit inputs; isWSL = true; };
          modules = [
            ./home/default.nix
            {
              home.username = "tonyh";
              home.homeDirectory = "/home/tonyh";
            }
          ];
        };

        # 2. CachyOS / Arch Linux (User: thsieh01, Home: /home/thsieh01)
        "cachyos" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          extraSpecialArgs = { inherit inputs; isWSL = false; };
          modules = [
            ./home/default.nix
            {
              home.username = "thsieh01";
              home.homeDirectory = "/home/thsieh01";
            }
          ];
        };

        # 3. macOS Darwin (User: thsieh01, Home: /Users/thsieh01)
        "darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."aarch64-darwin";
          extraSpecialArgs = { inherit inputs; isWSL = false; };
          modules = [
            ./home/default.nix
            ./home/darwin.nix
            {
              home.username = "thsieh01";
              home.homeDirectory = "/Users/thsieh01";
            }
          ];
        };
      };
    };
}
```

---

### 5.2 Core Home Manager Entry Point (`home/default.nix`)

```nix
{ pkgs, lib, extraSpecialArgs, ... }:

{
  imports = [
    ./packages.nix
    ./shell.nix
    ./tmux.nix
    ./starship.nix
    ./git.nix
    ./neovim.nix
    ./ai-agents.nix
  ] ++ lib.optional (extraSpecialArgs.isWSL or false) ./wsl.nix;

  # Enable Home Manager and Direnv
  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Common Session Variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    GOPATH = "$HOME/go";
  };

  # Let Home Manager manage release state
  home.stateVersion = "24.11";
}
```

---

### 5.3 Declarative Packages Module (`home/packages.nix`)

Replaces the manual package installation lists across `install-dev-env.sh`:

```nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Core CLI & File Inspection
    curl
    wget
    ripgrep
    jq
    yq-go
    bottom
    fzf
    bat
    eza
    fd

    # Cloud, Kubernetes & Secret Management
    kubectl
    kubernetes-helm
    fluxcd
    k9s
    kind
    sops
    age

    # Task Runners & Local Infrastructure
    just
    mkcert
    devenv

    # Terminal Helpers
    blesh
  ];
}
```

---

### 5.4 Reusable Common Devenv Module (`modules/devenv-common.nix`)

This module is imported by every project repository to enforce consistent standards:

```nix
{ pkgs, lib, config, ... }:

{
  # 1. Base tools required in every development shell
  packages = with pkgs; [
    git
    jq
    yq-go
    ripgrep
    just
    sops
  ];

  # 2. Standardized Git Pre-commit Hooks
  pre-commit.hooks = {
    nixpkgs-fmt.enable = true;
    trailing-whitespace-fixer.enable = true;
    end-of-file-fixer.enable = true;
    check-yaml.enable = true;
    check-json.enable = true;
  };

  # 3. Shell Hygiene & Conflict Protection
  enterShell = ''
    # Guard against active Conda environments
    if [ -n "''${CONDA_PREFIX:-}" ]; then
      echo "⚠️ Warning: Active Conda environment detected ('$CONDA_PREFIX')."
      echo "   Conda libraries can conflict with Nix packages. Please run 'conda deactivate'."
    fi

    # Display active devenv banner
    echo "❄️ Devenv workspace active ($(basename "$PWD"))"
  '';
}
```

---

## 🚦 6. Step-by-Step Migration Roadmap

The migration proceeds across **5 sequential phases** to allow zero-downtime, side-by-side validation:

```mermaid
flowchart TD
    P1["Phase 1: Bootstrap & Foundation"] --> P2["Phase 2: Home Manager Dotfiles"]
    P2 --> P3["Phase 3: AI Agents & Neovim"]
    P3 --> P4["Phase 4: Common Devenv Flake Module"]
    P4 --> P5["Phase 5: Local Container Mesh & Teardown of Old Scripts"]

    P1 -.->|"Validates"| V1["Nix & direnv active"]
    P2 -.->|"Validates"| V2["Bash, ble.sh, tmux, starship parity"]
    P3 -.->|"Validates"| V3["OpenCode, Hermes, LazyVim working"]
    P4 -.->|"Validates"| V4["Projects inherit devenv standards"]
    P5 -.->|"Validates"| V5["Clean rollback and deprecation"]
```

### Phase 1: Bootstrap & Flake Foundation
1. Verify Determinate Nix installation and ensure `experimental-features = nix-command flakes` is active.
2. Initialize root `flake.nix` and `flake.lock` in `setup-linux-scripts`.
3. Create `home/default.nix` and `home/packages.nix` with the core CLI package suite.
4. Test first build using `home-manager build --flake .#wsl`.

### Phase 2: Shell & Dotfile Migration
1. Migrate `.bashrc` into `home/shell.nix`:
   - Port aliases (`gs`, `gd`, `k`, `ll`, `la`, `up`).
   - Configure `blesh` integration and anti-lag latency settings.
   - Retain `[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local` local override hook.
2. Migrate `.tmux.conf` into `home/tmux.nix` using native `programs.tmux`:
   - Port vi-copy bindings and configure plugins via `tmuxPlugins.*`.
3. Configure `programs.starship` in `home/starship.nix`, symlinking `dotfiles/starship.toml`.
4. Migrate WSL-specific handlers (Wayland socket, Windows clipboard, OneDrive path discovery) to `home/wsl.nix`.

### Phase 3: AI Agents, Neovim & Secret Tooling
1. Port Neovim configuration to `home/neovim.nix` (installing Neovim via Nix and symlinking LazyVim starter configs).
2. Port OpenCode and Hermes configurations into `home/ai-agents.nix`:
   - Generate `~/.config/opencode/opencode.json` with MCP configurations.
   - Deploy `~/.config/opencode/skills/agy/SKILL.md` and `/agy` command markdown.
   - Generate `~/.hermes/config.yaml` with MCP definitions.
3. Establish one-time bootstrap script (`bootstrap/generate-keys.sh`) for idempotent `ssh-keygen` and `age-keygen`.

### Phase 4: Common Devenv Module & Starter Template
1. Create `modules/devenv-common.nix` exporting shared packages, pre-commit hooks, and Conda guards.
2. Create `templates/devenv-starter/` containing starter `flake.nix`, `devenv.nix`, and `.envrc`.
3. Verify that running `nix flake init -t .#default` in a test directory produces an instantly functional, direnv-activated developer workspace.

### Phase 5: Container Mesh Bridge & Deprecation of Procedural Scripts
1. Package the Tier 2 local container mesh into `local-services/` with a dedicated `justfile` (`jl`).
2. Verify Traefik v3 ingress, BentoPDF, Puppeteer MCP, and local Postgres under rootless Podman.
3. Deprecate `install-dev-env.sh` and update documentation (`README.md`).
4. Retain `uninstall-dev-env.sh` temporarily for legacy cleanup.

---

## 🛡️ 7. Rollback, Testing & Verification Strategy

| Test Scenario | Verification Command | Expected Outcome |
| :--- | :--- | :--- |
| **Nix Flake Validation** | `nix flake check` | All flake outputs and schemas evaluate cleanly without syntax errors. |
| **Home Manager Dry-Run** | `home-manager build --flake .#wsl` | Creates `./result` symlink containing user profile without mutating `$HOME`. |
| **Atomic Activation** | `home-manager switch --flake .#wsl` | Activates new environment atomically; updates symlinks in `$HOME`. |
| **Rollback Capability** | `home-manager generations` & `home-manager switch --generation <N>` | Instantly rolls back to previous generation if any configuration regresses. |
| **Direnv Project Test** | `cd /tmp/test-project && devenv init && direnv allow` | Project environment loads seamlessly in under 2 seconds. |
| **WSL Clipboard & Path Parity** | `echo "test" \| pbcopy && pbpaste` | Clipboard operates transparently across WSL2 and Windows host. |
| **AI Agent MCP Connection** | `jl status && curl -I http://puppeteer.mcp.localhost` | Local container mesh routes correctly through Traefik v3 with SSL. |

---

## 📌 8. Summary of Action Items

1. **Adopt 3-Tier Separation**:
   - Host (system daemons & private keys) $\rightarrow$ Home Manager (user tools & dotfiles) $\rightarrow$ Devenv (project toolchains).
2. **Standardize All Dev-Env Flakes**:
   - Centralize Cachix binary caching, Git pre-commit hooks, Conda conflict guards, and basic CLI tools in `modules/devenv-common.nix`.
3. **Execute Phased Migration**:
   - Start with Home Manager for packages and shell, then layer on AI agents and devenv templates, ensuring zero developer interruption.

# 🛠️ Devenv Best Practices & Guide

[Devenv](https://devenv.sh/) is a modern, fast, declarative developer environment manager built on top of [Nix](https://nixos.org/) and [Cachix](https://www.cachix.org/). It allows teams to specify project dependencies, services, environment variables, scripts, and pre-commit hooks in a single declarative `devenv.nix` file.

---

## 🌟 Core Benefits of Devenv

- **Declarative & Reproducible**: Defines software packages, environment variables, and services per repository so that every developer on the team runs identical toolchains.
- **Fast Startup & Binary Caching**: Integrates with Cachix to download pre-compiled binary packages instantly instead of compiling from source.
- **Isolated Shell Environments**: Automatically sets up project-specific shells without polluting your system `/usr` or global environment.
- **Built-in Service Management**: Spins up databases (PostgreSQL, MySQL, Redis), search engines, and mock API servers locally via process managers (`devenv up`).
- **Container Support**: Exports your exact developer environment directly into OCI/Docker container images (`devenv container build`).

---

## ⚙️ Installation & Architecture in this Repository (v2.0)

Our unified bootstrap script ([`bootstrap.sh`](../bootstrap.sh)) automates the setup of Devenv and Nix in a declarative, reproducible manner:

1. **Conflict Inspection**:
   - Checks if an active Conda environment (`$CONDA_PREFIX`) or conflicting Nix installation is present.
   - Outputs clear diagnostic guidance if Conda is active to prevent dynamic library and `PATH` conflicts.

2. **Determinate Nix Installation**:
   - If Nix is missing, installs Determinate Nix with Flakes and `nix-command` enabled out-of-the-box.

3. **Declarative Devenv Delivery**:
   - `devenv` is provisioned declaratively via Home Manager ([`home/packages.nix`](../home/packages.nix)).
   - No imperative distribution package managers (`apt`, `aur`, or `brew`) are used.

> [!TIP]
> For day-to-day project workflows, scaffolding templates, and real-world case studies, see **[`docs/day-to-day-workflow.md`](day-to-day-workflow.md)**.

---

## ⚠️ Conda & System Nix Conflict Mitigation

### Why Conda Conflicts with Nix / Devenv
Conda modifies shell execution paths (`PATH`) and environment search paths (`LD_LIBRARY_PATH`, `PYTHONPATH`). When a Conda environment is active:
- Conda's dynamic libraries (e.g. `libstdc++.so`, `libcrypto.so`) can override Nix-provided system libraries, resulting in `GLIBC` or symbol lookup errors.
- Conda binaries may shadow Nix binaries required inside `devenv shell`.

### Best Practice for Conda Users
Before entering a `devenv` shell, **always deactivate active Conda environments**:
```bash
# Deactivate active Conda environment
conda deactivate

# Verify environment is clear
echo $CONDA_PREFIX  # Should be empty
```

---

## 🔄 Interaction with Existing System Installations

When you navigate to a new repository/directory and activate a `devenv` shell (`devenv shell` or via `direnv`), `devenv` constructs a directory-scoped environment. Here is how your existing host system tools, packages, and environment settings interact with that `devenv` shell:

### 1. Executable Precedence & PATH Shadowing
`devenv` prepends its project-specific binaries (`.devenv/profile/bin` and Nix store paths) to the front of your `$PATH`:
- **Declared Tools (Shadowed)**: If `devenv.nix` specifies a language runtime or package (e.g., Node.js 20, Python 3.11, Rust, PostgreSQL), executing `node` or `python` inside that directory uses the **Nix store version**, completely shadowing any host OS installation (such as system Node.js 18 or Homebrew Python 3.12).
- **Undeclared Tools (Fallback)**: System utilities not declared in `devenv.nix` (e.g., `git`, `nvim`, `tmux`, `curl`, `docker`) remain fully accessible from your host system's standard `/usr/bin`, `/usr/local/bin`, or Homebrew paths.

### 2. Isolation of Language Dependencies & Packages
- **Python**: When `languages.python.venv.enable = true` is set, `devenv` creates an isolated virtual environment inside `.devenv/state/venv`. System-wide `pip` packages or host site-packages are isolated and will not leak into the project shell.
- **Node.js**: Dependencies are managed locally in `./node_modules`. Global npm modules on your host OS (`/usr/local/lib/node_modules`) are bypassed inside `devenv shell`.
- **Rust**: Uses the project-specified Rust toolchain and builds inside `./target` without modifying global `~/.cargo/bin`.

### 3. Environment Variable Precedence
- Environment variables explicitly defined in `devenv.nix` (`env.DATABASE_URL = "..."`) override host shell environment variables of the same name.
- Non-conflicting host environment variables (such as `$USER`, `$HOME`, `$TERM`, or custom variables defined in `~/.bashrc.local`) are inherited automatically.

### 4. Integration with Host System Daemons & Hardware
- **Docker & Containers**: The `docker` CLI inside `devenv` connects to your host OS Docker daemon via `/var/run/docker.sock` (or WSL2/macOS socket bridges), allowing seamless container orchestration.
- **SSH & Git**: `devenv` inherits your host's active SSH agent (`$SSH_AUTH_SOCK`), global `~/.gitconfig`, and declarative `~/.config/git/config` (including `push.autoSetupRemote = true` and native git aliases from `home/git.nix`), so SSH authentication, commit identities, and automatic upstream push tracking work seamlessly without re-configuration inside project workspaces.
- **WSL2 NVIDIA GPU Acceleration**: When running under WSL2, Windows paravirtualizes GPU access through `/dev/dxg` and `/usr/lib/wsl/lib`. Because Nix binaries bypass the host dynamic linker cache, our Python templates automatically inject `/usr/lib/wsl/lib` into `LD_LIBRARY_PATH` on directory entry (see detailed architecture below).

### 5. Pure vs. Impure Shell Modes (Recommendation for New Repositories)

- **Local Interactive Development (Recommended: Impure Mode)**:
  When developing interactively on your workstation, use standard **Impure Mode** (`devenv shell` or `direnv`). This preserves your host editor (`nvim`, `zed`), terminal prompt (`starship`), terminal multiplexer (`tmux`), and active SSH agent while guaranteeing directory-scoped toolchains.

- **CI/CD & Verification (Recommended: Pure Mode)**:
  Use **Pure Mode** (`devenv shell --pure` or `devenv test`) for CI/CD pipelines, container builds, and pre-merge verification. Pure mode strips all host environment variables and system `$PATH` entries, guaranteeing that your repository's `devenv.nix` is 100% self-contained and reproducible on any computer or build server.

> [!TIP]
> **Recommended Workflow for New Repositories**:
> 1. **Initialize**: Run `devenv init` and create `.envrc` (`use devenv`).
> 2. **Declare Explicitly**: Add all required toolchains, build tools (e.g. `pkgs.git`, `pkgs.jq`, `pkgs.ripgrep`), and services to `devenv.nix`.
> 3. **Develop**: Use standard `devenv shell` or `direnv allow` for interactive day-to-day work.
> 4. **Validate**: Run `devenv shell --pure` or `devenv test` before pushing to ensure zero reliance on un-declared host binaries.
> 5. **Lock**: Commit `devenv.lock` alongside `devenv.nix` and `devenv.yaml`.

---

## 🚀 Quickstart & Essential Workflows

### 1. Initialize Devenv in a Project
Navigate to your repository root and initialize `devenv`:
```bash
devenv init
```
This generates two files:
- `devenv.nix`: Main declarative configuration file.
- `devenv.yaml`: Configuration for inputs and Nix channels.

### 2. Basic `devenv.nix` Example
Below is an example `devenv.nix` configured for a multi-language (Node.js + Python + Rust + Postgres) stack:

```nix
{ pkgs, lib, config, inputs, ... }:

{
  # 1. Packages to expose in PATH
  packages = [
    pkgs.git
    pkgs.ripgrep
    pkgs.jq
  ];

  # 2. Programming Languages & Runtimes
  languages.javascript = {
    enable = true;
    npm.enable = true;
  };

  languages.python = {
    enable = true;
    venv.enable = true;
  };

  languages.rust.enable = true;

  # 3. Environment Variables
  env.PORT = "8080";
  env.DATABASE_URL = "postgres://localhost:5432/myapp_dev";

  # 4. Local Background Services
  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "myapp_dev"; }];
  };

  # 5. Enter Shell Hook
  enterShell = ''
    echo "🚀 Entering Devenv workspace for myapp!"
    echo "Node version: $(node -v)"
    echo "Python version: $(python --version)"
  '';

  # 6. Pre-commit Hooks
  pre-commit.hooks = {
    nixpkgs-fmt.enable = true;
    rustfmt.enable = true;
  };
}
```

### 3. Entering the Environment Shell
To enter your isolated developer environment:
```bash
devenv shell
```
*(Or `devenv enter`)*. All tools, variables, and language runtimes defined in `devenv.nix` will be immediately available in your prompt.

### 4. Automatic Shell Loading via `direnv`
Combine `devenv` with `direnv` to automatically load environment settings whenever you `cd` into the project directory:
1. Create an `.envrc` file in your project root:
   ```bash
   echo "use devenv" > .envrc
   ```
2. Allow `direnv`:
   ```bash
   direnv allow
   ```

### 5. Running Local Background Services
Start all local databases and services declared under `services.*` in `devenv.nix`:
```bash
devenv up
```
To stop running background services, press `Ctrl+C`.

---

## 💡 Recommended Best Practices

1. **Lock Dependencies with `devenv.lock`**:
   - Commit `devenv.yaml`, `devenv.nix`, and `devenv.lock` to Git.
   - Run `devenv update` periodically to pull locked updates for underlying Nix packages.

2. **Use Binary Caches (Cachix)**:
   - Configure a binary cache to eliminate build times for heavy dependencies:
     ```bash
     devenv use <cache-name>
     ```

3. **Define Task Automation in `scripts`**:
   - Add reusable project scripts in `devenv.nix`:
     ```nix
     scripts.test.exec = "cargo test && npm test";
     scripts.db-reset.exec = "dropdb myapp_dev && createdb myapp_dev";
     ```
   - Execute them simply with:
     ```bash
     devenv test
     ```

4. **Container Image Generation**:
   - Build a production or CI container image matching your exact devenv environment:
     ```bash
     devenv container build
     ```

---

## 📚 Built-In Project Flake Templates (Multi-Language Stack Catalog)

This repository provides production-ready, declarative Nix Flake templates for modern development stacks. Each template implements a standardized **3-file declarative pattern**:

```text
my-project/
├── flake.nix      # Flake entry point calling devenv.lib.mkShell
├── devenv.nix     # Declarative languages, compilers, CLI tools, scripts & hooks
└── .envrc         # Direnv activation with automatic dependency manifest watching
```

### ⚡ The Dual-Condition Dependency Auto-Sync Pattern
All templates adhere to our **Phase 5 auto-sync standard**:
1. **Zero-Error Initialization**: When first initialized via `nix flake init`, the environment never crashes if project manifest files (e.g. `package.json`, `Cargo.toml`, `go.mod`, `build.sbt`) have not yet been created.
2. **Helpful Scaffolding Guidance**: `enterShell` displays a friendly terminal banner advising the developer on the idiomatic command to initialize the project (e.g., `pnpm init`, `cargo init`, `go mod init`, `sbt new zio/zio-seed.g8`).
3. **Automatic Change Detection (`watch_file`)**: The pre-configured `.envrc` watches language dependency manifests. As soon as you save or modify a manifest file, `direnv` automatically reloads the shell and executes the fast native package manager (`pnpm install`, `go mod download`, `cargo check`).

---

### 🗂️ Template Catalog & Capabilities Matrix

| Stack | Initialize Command | Key Toolchains & Packages | Auto-Watched Manifests | Primary Strengths |
| :--- | :--- | :--- | :--- | :--- |
| **Go** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#go` | Go 1.23+, `gopls`, `golangci-lint`, `delve` (`dlv`), `gotools` | `go.mod`, `go.sum` | Zero-dependency microservices, high-concurrency APIs, CLI tools |
| **Rust / WASM** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#wasm`<br>*(or `#rust-wasm`)* | Rust `wasm32-unknown-unknown`, `wasm-pack`, `wasm-bindgen-cli`, `binaryen` (`wasm-opt`), `wabt`, `rust-analyzer` | `Cargo.toml`, `Cargo.lock` | High-performance WebAssembly in browser/Node, client-side PDF/image compute (like BentoPDF) |
| **TypeScript / Effect** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#effect`<br>*(or `#ts-effect`)* | Node.js 22, pnpm, `tsx`, Biome linter/formatter, Effect-TS ecosystem | `package.json`, `pnpm-lock.yaml`, `tsconfig.json` | Type-safe functional programming, structured concurrency, typed errors, resilient backend services |
| **Scala 3 / ZIO** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#zio`<br>*(or `#scala-zio`)* | Eclipse Temurin Java 21 LTS, Scala 3, `sbt`, `scala-cli`, `scalafmt`, Metals LSP | `build.sbt`, `project/build.properties`, `project.scala` | Purely functional, type-driven asynchronous microservices, resilient concurrent pipelines |
| **Node.js / TS** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#node` | Node.js 22, TypeScript, pnpm, Biome | `package.json`, `pnpm-lock.yaml` | Standard full-stack web apps, REST/GraphQL APIs, CLI scripts |
| **Python / ML** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#python` | Python 3.12, `uv` fast manager, `ruff`, WSL2 CUDA paravirtualization | `requirements.txt`, `pyproject.toml` | Machine Learning, PyTorch, LLM agents, local CUDA acceleration on RTX GPUs |
| **Systems Rust** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#rust` | Rust stable, `cargo-watch`, `cargo-edit`, `rust-analyzer` | `Cargo.toml`, `Cargo.lock` | Native systems programming, daemon tools, high-speed CLI utilities |
| **Kubernetes** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#kubernetes`<br>*(or `#ckad`)* | `kubectl`, `minikube`, `helm`, `k9s`, `kustomize`, exam shorthands | `kustomization.yaml`, `Chart.yaml`, `values.yaml` | Cloud-native deployments, CKAD / CKA certification labs, microservice orchestration |
| **Minimal Starter** | `nix flake init -t github:TonyHsieh/setup-linux-scripts` | Reusable common module, pre-commit hooks, `git`, `jq`, `yq-go` | `flake.nix`, `devenv.nix` | Lightweight boilerplate for generic shell scripting or custom tools |

---

### 📖 In-Depth Template Reference

#### 1. Go Developer Environment (`#go`)
* **Scaffolding**:
  ```bash
  mkdir my-go-service && cd my-go-service
  nix flake init -t github:TonyHsieh/setup-linux-scripts#go
  direnv allow
  ```
* **Toolchains Included**:
  * `languages.go.enable = true` (Go 1.23+)
  * `pkgs.gopls`: Official Go language server protocol daemon.
  * `pkgs.golangci-lint`: Fast multi-linter runner.
  * `pkgs.delve`: The premier Go debugger (`dlv`).
  * `pkgs.gotools`: Standard Go formatting and refactoring utilities (`goimports`, etc.).
* **Auto-Sync Hook**:
  ```bash
  if [ -f go.mod ]; then
    echo "📦 Syncing Go module dependencies from go.mod..."
    go mod download 2>/dev/null || echo "💡 Run 'go mod tidy' to synchronize module requirements."
  fi
  ```

#### 2. Rust & WebAssembly / WASM (`#wasm`, `#rust-wasm`)
* **Scaffolding**:
  ```bash
  mkdir my-wasm-app && cd my-wasm-app
  nix flake init -t github:TonyHsieh/setup-linux-scripts#wasm
  direnv allow
  ```
* **Toolchains Included**:
  * `languages.rust = { enable = true; channel = "stable"; targets = [ "wasm32-unknown-unknown" ]; }`
  * `pkgs.wasm-pack`: All-in-one tool for building and packaging Rust-generated WebAssembly for the browser or npm.
  * `pkgs.wasm-bindgen-cli`: High-level interactions between Rust and JavaScript.
  * `pkgs.binaryen`: Provides `wasm-opt` (production code size & speed optimization) and `wasm-merge`.
  * `pkgs.wabt`: The WebAssembly Binary Toolkit (`wasm2wat`, `wat2wasm`).
  * `pkgs.rust-analyzer` & `pkgs.cargo-watch`.
* **Workflow**:
  ```bash
  wasm-pack build --target web      # Compile Rust directly into browser-ready WASM + JS glue
  wasm-opt -O3 pkg/my_app_bg.wasm -o pkg/my_app_bg.opt.wasm # Optimize payload size
  ```

#### 3. TypeScript & Effect-TS (`#effect`, `#ts-effect`)
* **Scaffolding**:
  ```bash
  mkdir my-effect-app && cd my-effect-app
  nix flake init -t github:TonyHsieh/setup-linux-scripts#effect
  direnv allow
  ```
* **Toolchains Included**:
  * `languages.javascript` (Node.js 22 LTS) + `languages.typescript.enable = true`
  * `pnpm.enable = true`: Fast, disk-efficient package manager.
  * `pkgs.tsx`: Blazing-fast TypeScript script execution engine (runs `.ts` files with zero build step).
  * `pkgs.biome`: Next-generation ultra-fast linter and formatter.
* **Effect Ecosystem Guidance**:
  The environment displays guidance to seed modern functional TypeScript dependencies:
  ```bash
  pnpm init
  pnpm add effect @effect/schema @effect/platform
  pnpm add -D typescript @types/node tsx biome vitest
  ```

#### 4. Scala 3 & ZIO (`#zio`, `#scala-zio`)
* **Scaffolding**:
  ```bash
  mkdir my-zio-service && cd my-zio-service
  nix flake init -t github:TonyHsieh/setup-linux-scripts#zio
  direnv allow
  ```
* **Toolchains Included**:
  * `languages.java.jdk.package = pkgs.temurin-bin-21`: Eclipse Temurin Java 21 LTS runtime.
  * `languages.scala = { enable = true; sbt.enable = true; }`: Scala 3 runtime and sbt build tool.
  * `pkgs.scala-cli`: Revolutionary single-file Scala runner and prototyping tool.
  * `pkgs.scalafmt`: Code formatting engine.
  * `pkgs.metals`: Metals Language Server for Neovim / VS Code / Zed integration.
* **Workflow**:
  ```bash
  # Quick single-file script with ZIO:
  cat << 'EOF' > Main.scala
  //> using scala 3.5.2
  //> using dep dev.zio::zio:2.1.13
  import zio._

  object Main extends ZIOAppDefault:
    def run = Console.printLine("Hello from ZIO and Devenv!")
  EOF

  scala-cli run .
  ```

---

## 🎮 WSL2 NVIDIA & CUDA GPU Acceleration (Machine Learning & PyTorch)

When running Machine Learning, Deep Learning (e.g. PyTorch, Hugging Face Transformers, SentencePiece), or CUDA compute workloads inside **WSL2** (Windows Subsystem for Linux), standard Linux GPU workflows require specific understanding of the paravirtualized driver stack and Nix linker behavior.

### 1. Paravirtualized WSL2 GPU Driver Architecture
* **Windows Host Driver**: The actual NVIDIA GPU kernel driver is installed exclusively on the **Windows host OS**. Do not attempt to install native Linux `.run` or `apt` NVIDIA driver packages inside WSL2.
* **Driver Shims (`/usr/lib/wsl/lib`)**: WSL2 paravirtualizes GPU access through the DirectX Graphics Kernel device (`/dev/dxg`). Windows automatically mounts user-mode driver libraries into `/usr/lib/wsl/lib`:
  - `libcuda.so` / `libcuda.so.1` (CUDA Driver API)
  - `libnvidia-ml.so.1` (NVML telemetry)
  - `nvidia-smi` (Hardware monitoring utility)
  - `libdxcore.so` & `libd3d12core.so`

### 2. The Nix Linker Gotcha (`Found no NVIDIA driver`)
* **Standard Ubuntu Linux**: Uses glibc and `/etc/ld.so.cache`. WSL generates `/etc/ld.so.conf.d/ld.wsl.conf` pointing to `/usr/lib/wsl/lib`, allowing standard distribution binaries to resolve `libcuda.so.1` automatically.
* **Nix / Devenv Shells**: Nix-built binaries (including Python interpreters provisioned via `languages.python.enable = true;`) use custom RPATH/RUNPATH headers pointing directly to `/nix/store/...` and **completely ignore `/etc/ld.so.cache`**.
* **The Symptom**: In a Devenv shell or Nix Python environment, `torch.cuda.is_available()` returns `False` or raises:
  ```text
  UserWarning: CUDA initialization: Found no NVIDIA driver on your system.
  ```
  even though `nvidia-smi` works!

### 3. The Declarative, Zero-Pollution Solution

We avoid setting a blind global `export LD_LIBRARY_PATH=/usr/lib/wsl/lib` in `~/.bashrc`, which can interfere with Nix compiler toolchains. Instead, we use a three-tiered declarative pattern:

#### Tier A: Automated Project Wiring in `devenv.nix`
In [`templates/python/devenv.nix`](../templates/python/devenv.nix), `enterShell` automatically detects WSL2 and forwards the library path:

```nix
{ pkgs, ... }:

{
  languages.python = {
    enable = true;
    venv.enable = true;
    uv.enable = true;
  };

  # Native libraries for C++ wheels (SentencePiece, PyTorch)
  packages = with pkgs; [
    stdenv.cc.cc.lib
    zlib
  ];

  enterShell = ''
    # 1. WSL2 GPU Acceleration: expose Windows NVIDIA CUDA driver shims
    if [ -d "/usr/lib/wsl/lib" ]; then
      export LD_LIBRARY_PATH="/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      if [[ ":$PATH:" != *":/usr/lib/wsl/lib:"* ]]; then
        export PATH="/usr/lib/wsl/lib:$PATH"
      fi
    fi

    # 2. Self-Healing Virtualenv Hook: preserve CUDA path if devenv rebuilds the venv
    if [ -n "''${VIRTUAL_ENV:-}" ] && [ -f "$VIRTUAL_ENV/bin/activate" ] && [ -d "/usr/lib/wsl/lib" ]; then
      if ! grep -q "/usr/lib/wsl/lib" "$VIRTUAL_ENV/bin/activate"; then
        echo "" >> "$VIRTUAL_ENV/bin/activate"
        echo "# WSL2 GPU Acceleration: expose Windows NVIDIA CUDA driver shims" >> "$VIRTUAL_ENV/bin/activate"
        echo 'if [ -d "/usr/lib/wsl/lib" ]; then' >> "$VIRTUAL_ENV/bin/activate"
        echo '    export LD_LIBRARY_PATH="/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"' >> "$VIRTUAL_ENV/bin/activate"
        echo 'fi' >> "$VIRTUAL_ENV/bin/activate"
      fi
    fi
  '';
}
```

* **Directory Scoping via Direnv**: When you `cd` into the repo, `direnv` loads the environment and adds `/usr/lib/wsl/lib` to `LD_LIBRARY_PATH`. When you `cd ..` out, `direnv` completely cleans `LD_LIBRARY_PATH`, leaving your global shell spotless.
* **Standalone Venv Compatibility**: If you launch scripts, tests, or Jupyter kernels using `source .devenv/state/venv/bin/activate` outside of direnv, the venv activation hook ensures full CUDA access.

#### Tier B: Host Shell Helpers for Ad-Hoc Venvs
In [`home/wsl.nix`](../home/wsl.nix), two convenient shell functions are provided for ad-hoc environments:
1. **`wsl-cuda`**: Immediately exports `/usr/lib/wsl/lib` to `LD_LIBRARY_PATH` for the current bash session.
2. **`patch-venv-cuda [venv_path]`**: Permanently patches any plain virtual environment (e.g., created with `uv venv` or `python -m venv` outside Devenv):
   ```bash
   patch-venv-cuda .venv
   ```

### 4. Verification Check
To verify CUDA driver access inside your active Python environment:
```bash
python -c 'import torch; print("CUDA:", torch.cuda.is_available(), "| GPU:", torch.cuda.get_device_name(0))'
```
**Expected Output:**
```text
CUDA: True | GPU: NVIDIA GeForce RTX 4070 Laptop GPU
```

---

## ⚡ Performance Tuning & Eliminating Shell Lag

If you experience long initial startup times or terminal input freezing when entering a `devenv` shell, here is why it happens and how it is optimized:

### 1. Initial Evaluation Time (e.g. ~1m 24s) vs. Cached Runs (< 1s)
- **First-Time Evaluation**: On the first run, Nix evaluates thousands of `nixpkgs` package definitions to resolve your `devenv.nix` environment.
- **Cached Subsequent Runs**: Once evaluated, Nix caches the profile in `.devenv/profile`. Subsequent runs in the same workspace load in less than 1 second.
- **Instant Shell Loading with `direnv`**: Instead of manually running `devenv shell` (which launches a new subshell process), use `direnv`. `direnv` caches environment variables in the background and activates them **instantly (<10ms)** as soon as you `cd` into the project directory:
  ```bash
  echo "use devenv" > .envrc
  direnv allow
  ```

### 2. Eliminating Terminal Freeze & Input Lag (`ble.sh` / Starship)
- **The Issue**: When entering complex subshells, interactive Bash line editors like `ble.sh` attempt to synchronously evaluate completions and highlight syntax across extensive PATH entries, which can cause input processing stalls like `(98.1% processing input...)` and triggering `devenv paused`.
- **The Fix**: In our system `.bashrc`, we configure asynchronous syntax highlighting and a typing delay so auto-completion triggers smoothly without freezing input:
  ```bash
  bleopt complete_auto_delay=200
  bleopt highlight_timeout_sync=0
  ```
- **Re-deploy Configuration**: Run `./bootstrap.sh` or `exec bash` to apply this optimization to your active shell session.

---

## 🧹 Maintenance & Cleanup

To clean unused Nix store entries and free up disk space:
```bash
# Garbage collect devenv caches
devenv gc

# Garbage collect Nix store
nix-collect-garbage -d
```

To roll back or inspect previous user environment generations:
```bash
home-manager generations
home-manager switch --generation <ID>
```


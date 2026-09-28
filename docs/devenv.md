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

## ⚙️ Installation & Architecture in this Repository

Our setup script ([`install-dev-env.sh`](file:///home/tonyh/_Projects/setup-linux-scripts/install-dev-env.sh)) automates the setup of Devenv and Nix in an **idempotent** manner:

1. **Conflict Inspection**:
   - Checks if an active Conda environment (`$CONDA_PREFIX`) or conflicting Nix installation is present.
   - Outputs clear diagnostic guidance if Conda is active to prevent dynamic library and `PATH` conflicts.

2. **Nix Package Manager Setup**:
   - If Nix is missing, installs Nix using the cross-platform [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer) with Flakes and `nix-command` enabled out-of-the-box.

3. **Devenv CLI Installation**:
   - **Arch Linux / CachyOS**: Installed via `devenv-bin` in AUR (or official installer script fallback).
   - **macOS**: Installed via Homebrew (`brew install devenv`).
   - **Debian / Ubuntu**: Installed via official installer script (`curl -fsSL https://devenv.sh/install | sh`).

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

### 4. Integration with Host System Daemons
- **Docker & Containers**: The `docker` CLI inside `devenv` connects to your host OS Docker daemon via `/var/run/docker.sock` (or WSL2/macOS socket bridges), allowing seamless container orchestration.
- **SSH & Git**: `devenv` inherits your host's active SSH agent (`$SSH_AUTH_SOCK`) and global `~/.gitconfig`, so SSH authentication and Git commit identities work out of the box without re-configuration inside the directory.

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
- **The Issue**: When entering a `devenv` shell, Nix prepends `/nix/store/...` paths containing thousands of executables to your `$PATH`. Interactive Bash line editors like `ble.sh` attempt to recursively scan every Nix store binary for autocompletion, causing input processing stalls like `(98.1% processing input...)` and triggering `devenv paused`.
- **The Fix**: In our system `.bashrc`, we explicitly exclude `/nix/store/*` from `ble.sh` path scanning:
  ```bash
  ble/path#remove-glob PATH '/nix/store/*'
  ble/path#remove-glob PATH '/nix/*'
  ```
- **Re-deploy Configuration**: Run `./install-dev-env.sh` or `source ~/.bashrc` to apply this optimization to your active shell session.

---

## 🧹 Maintenance & Cleanup

To clean unused Nix store entries and free up disk space:
```bash
# Garbage collect devenv caches
devenv gc

# Garbage collect Nix store
nix-collect-garbage -d
```

To completely uninstall `devenv` and Nix from your system:
```bash
./uninstall-dev-env.sh
```

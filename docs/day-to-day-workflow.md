# 📖 Day-to-Day Developer Guide: Nix, Devenv, Traefik, & Just

This guide provides practical, step-by-step instructions for working with the **v2.0 Declarative Architecture** on a daily basis. It explains how to add new tools across all tiers, how to route web apps through Traefik, and demonstrates a real-world case study on **adapting imperative tutorial repositories (such as Sander van Vugt's CKAD course)** into clean, isolated Nix/Devenv environments.

---

## 🏛️ 1. Understanding the 3 Tiers (Where Does My Change Go?)

Before editing configuration files, identify which tier your change belongs to:

| Tier | Scope | What Lives Here | How to Modify |
| :--- | :--- | :--- | :--- |
| **Tier 1: Global User** | All shells & folders | CLI tools (`git`, `jq`, `sops`), shell aliases, tmux, starship, neovim | Edit files in [`home/`](../home/), then run `./bootstrap.sh` |
| **Tier 2: Local Mesh** | Local machine services | Traefik v3 proxy, local Postgres, BentoPDF, future apps (Ollama, Kavita, Plex) | Edit [`local-services/`](../local-services/), manage via `jl` |
| **Tier 3: Project Workspaces** | Specific project directory | Compilers (Node, Python, Rust, Go), project linters, mock DBs, pre-commit hooks | Edit `devenv.nix` in that project folder |

---

## 🛠️ 2. Tier 1: Adding Global Tools, Aliases, & Packages

### 2.1 Adding a Global CLI Package
If you need a command-line tool available everywhere across your system:

1. Search for the package name in [Nixpkgs Search](https://search.nixos.org/packages) or via CLI:
   ```bash
   nix search nixpkgs <tool-name>
   ```
2. Open [`home/packages.nix`](../home/packages.nix) and add the package attribute:
   ```nix
   home.packages = with pkgs; [
     # Existing tools...
     git
     jq

     # Add your new tool:
     htop
     duf
   ];
   ```
3. Apply the change atomically:
   ```bash
   ./bootstrap.sh
   ```
4. Verify:
   ```bash
   which htop
   # -> /home/tonyh/.nix-profile/bin/htop
   ```

### 2.2 Adding Custom Aliases & Shell Variables

Depending on whether an alias or environment variable should be **shared across all your machines** or **kept private / machine-specific**, choose between:

#### Option A: Permanent & Version-Controlled Aliases (`home/shell.nix`)
Use this for developer shorthands you want tracked in Git and replicated across all your machines:

1. Open [`home/shell.nix`](../home/shell.nix).
2. Add your alias to `programs.bash.shellAliases`:
   ```nix
   shellAliases = {
     # Existing aliases...
     k = "kubectl";

     # Add your new alias:
     tf = "terraform";
     ag = "antigravity";
   };
   ```
3. Apply changes with `./bootstrap.sh` and reload your shell (`exec bash`).

#### Option B: Machine-Specific, Private, or Quick Aliases (`~/.bashrc.local`)
Use this for private API keys, work-only tokens, machine-specific paths, or quick temporary aliases you don't want committed to Git:

1. Open or create `~/.bashrc.local`:
   ```bash
   # Add machine-specific aliases:
   alias ag="antigravity"
   alias myproj="cd ~/work/client-project"

   # Add private API keys (never committed to Git):
   export GEMINI_API_KEY="AIzaSy..."
   ```
2. `~/.bashrc.local` is automatically sourced by `~/.bashrc` at startup and takes effect immediately without needing `./bootstrap.sh` or a Home Manager rebuild. Reload with `source ~/.bashrc`.

---

## 🌐 3. Tier 2: Routing Containers through Traefik with SSL

All local container services route through **Traefik v3** with automated, trusted SSL certificates (`*.localhost`). You never need to remember port numbers or accept self-signed browser warnings.

### 3.1 Adding a New Container Service
To add a new service (e.g. an e-book server, local AI, or dashboard) to the mesh:

1. Open [`local-services/docker-compose.yml`](../local-services/docker-compose.yml).
2. Add your service with standard Traefik routing labels:
   ```yaml
     # 📖 Kavita E-Book / Manga Server
     kavita:
       image: lscr.io/linuxserver/kavita:latest
       container_name: local-kavita
       restart: unless-stopped
       environment:
         - PUID=1000
         - PGID=1000
         - TZ=America/Los_Angeles
       volumes:
         - kavita-data:/config
         - /mnt/d/Books:/data/books:ro   # Mount your host books directory
       networks:
         - local-mesh
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.kavita.rule=Host(`kavita.localhost`)"
         - "traefik.http.routers.kavita.entrypoints=web,websecure"
         - "traefik.http.routers.kavita.tls=true"
         - "traefik.http.services.kavita.loadbalancer.server.port=5000"
   ```
3. Update the `mkcert` certificate recipe in [`local-services/justfile`](../local-services/justfile) if you want the subdomain explicitly listed in the SAN:
   ```just
   mkcert -cert-file ... "*.localhost" "localhost" "pdf.localhost" "traefik.localhost" "kavita.localhost" "127.0.0.1" "::1"
   ```
4. Spin up the updated mesh:
   ```bash
   jl certs   # Regenerates certificate with new SAN
   jl up      # Starts/recreates containers
   ```
5. Open your browser: `https://kavita.localhost` (clean HTTPS padlock, zero warnings).

---

## 📦 4. Tier 3: Daily Project Work with Devenv

Every repository should declare its own isolated toolchains so your global system remains unpolluted.

### 4.1 Quick Scaffolding with Built-In Flake Templates
When starting or cloning a project, initialize from our repository templates:

```bash
# 1. Node.js 22, TypeScript, pnpm, Biome
nix flake init -t github:TonyHsieh/setup-linux-scripts#node

# 2. Python 3.12, uv, ruff
nix flake init -t github:TonyHsieh/setup-linux-scripts#python

# 3. Systems Rust, cargo-watch, rust-analyzer
nix flake init -t github:TonyHsieh/setup-linux-scripts#rust

# 4. Kubernetes & CKAD (kubectl, minikube, helm, k9s)
nix flake init -t github:TonyHsieh/setup-linux-scripts#kubernetes

# 5. Minimal starter
nix flake init -t github:TonyHsieh/setup-linux-scripts
```

### 4.2 Activating the Environment
```bash
# Enable direnv automatic activation (recommended)
direnv allow

# OR run an interactive subshell
devenv shell
```

---

## 🎓 5. Real-World Case Study: Adapting Sander van Vugt's CKAD Course

A common dilemma when learning or taking courses online (e.g. Linux Foundation, Udemy, A Cloud Guru) is that course repositories instruct students to run imperative setup scripts that can break modern systems.

### 5.1 The Problem in the Course Repository
In Sander van Vugt's repository ([`sandervanvugt/ckad`](https://github.com/sandervanvugt/ckad)), the setup script (`minikube-docker-setup.sh`) executes:
```bash
# What the course script does:
sudo apt-get install docker-ce ...
curl -LO https://storage.googleapis.com/.../kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
curl -LO https://storage.googleapis.com/minikube/.../minikube
sudo install minikube /usr/local/bin/minikube
sudo usermod -aG docker $USER
```

#### Why You Should NEVER Run This Script on Your Nix Machine:
1. **Global Contamination**: It places unversioned binaries directly into `/usr/local/bin`, shadowing Nix packages and preventing reproducible upgrades.
2. **Apt & Daemon Clashes**: It attempts to install legacy Docker and modify `/etc/apt/keyrings`, clashing with unprivileged rootless Podman.
3. **Rollback Impossibility**: It leaves behind stale files with no uninstall trail.

---

### 5.2 The 4-Step Declarative Adaptation Blueprint

Here is how you adapt **any** imperative course or tutorial repository into your clean environment:

#### Step 1: Clone the Course Repository
```bash
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/sandervanvugt/ckad.git
cd ckad
```

#### Step 2: Initialize the Kubernetes Devenv Stack
Instead of running `minikube-docker-setup.sh`, drop in our declarative Kubernetes template:

```bash
nix flake init -t github:TonyHsieh/setup-linux-scripts#ckad
```

This generates a project-scoped `devenv.nix`:
```nix
{ pkgs, ... }:

{
  packages = with pkgs; [
    kubectl
    minikube
    kubernetes-helm
    k9s
    kustomize
    yq-go
    jq
  ];

  enterShell = ''
    alias k=kubectl
    complete -o default -F __start_kubectl k 2>/dev/null || true
    source <(kubectl completion bash 2>/dev/null) 2>/dev/null || true

    export do="--dry-run=client -o yaml"
    export now="--force --grace-period=0"

    echo "☸️  CKAD & Kubernetes Environment Loaded!"
  '';
}
```

#### Step 3: Prevent Git Tracking of Nix Artifacts in the Course Repo
Add Nix temporary directories to the local repository git exclude:
```bash
echo -e "\n.devenv*\n.direnv/\nflake.lock" >> .git/info/exclude
```

#### Step 4: Allow Direnv & Start Minikube
```bash
# 1. Activate the environment
direnv allow

# 2. Start Minikube cleanly via rootless Podman (or Docker Desktop)
minikube start --driver=podman --container-runtime=containerd

# 3. Enable CKAD course addons
minikube addons enable ingress
minikube addons enable metrics-server
```

---

### 5.3 Daily Practice Workflow with the Course Labs

Once initialized, working with course manifests is seamless:

```bash
# Verify cluster status
k get nodes

# Practice generating manifests on the fly (Exam Tip)
k create deploy web-app --image=nginx:alpine $do > web-app.yaml

# Apply and test course exercises
k apply -f pods-with-nw-policy.yaml
k apply -f canary.yaml

# Visual inspection with k9s (super fast during practice)
k9s

# When finished practicing for the day:
minikube stop

# Leave the directory
cd ..
# (All Kubernetes tools disappear from your shell instantly, leaving zero clutter)
```

---

## ⚡ 6. Quick Reference Cheat Sheet

| Task | Command | Target Tier |
| :--- | :--- | :--- |
| **Apply repo changes** | `./bootstrap.sh` | Tier 1 (Home Manager) |
| **Test flake syntax** | `nix flake check` | Global |
| **Start local mesh** | `jl up` | Tier 2 (Containers) |
| **Mesh service status** | `jl status` | Tier 2 (Containers) |
| **Regen local SSL** | `jl certs` | Tier 2 (Traefik) |
| **Scaffold new Node app** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#node` | Tier 3 (Project) |
| **Scaffold new Python app**| `nix flake init -t github:TonyHsieh/setup-linux-scripts#python` | Tier 3 (Project) |
| **Scaffold new Rust app** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#rust` | Tier 3 (Project) |
| **Scaffold CKAD / K8s** | `nix flake init -t github:TonyHsieh/setup-linux-scripts#ckad` | Tier 3 (Project) |
| **Activate project shell** | `direnv allow` or `devenv shell` | Tier 3 (Project) |
| **Roll back generation** | `home-manager generations` & `home-manager switch --generation <ID>` | Tier 1 (History) |

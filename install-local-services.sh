#!/usr/bin/env bash
# ==============================================================================
# install-local-services.sh
# Purpose: Idempotent setup of local container mesh using Podman, Traefik v3,
#          mkcert (local SSL), justfile, containerized MCP servers, & BentoPDF.
# Target: CachyOS / Arch Linux, WSL2-Ubuntu / Debian Linux, and macOS
# ==============================================================================
set -euo pipefail

# 1. Detect OS family and WSL status
detect_os() {
  OS_FAMILY="unknown"
  if [ "$(uname)" = "Darwin" ]; then
    OS_FAMILY="macos"
  elif command -v pacman >/dev/null 2>&1; then
    OS_FAMILY="arch"
  elif command -v apt-get >/dev/null 2>&1; then
    OS_FAMILY="debian"
  fi

  IS_WSL=false
  if [ "$OS_FAMILY" != "macos" ] && grep -qsi Microsoft /proc/version; then
    IS_WSL=true
  fi
}

detect_os
echo "==> Detected OS Family: $OS_FAMILY (WSL: $IS_WSL)"

if [ "$OS_FAMILY" = "unknown" ]; then
  echo "❌ Error: Unsupported system. Supported: macOS (Homebrew), Arch Linux/CachyOS (pacman), Debian/Ubuntu (apt)." >&2
  exit 1
fi

# 1.5. Prerequisite Check: Ensure install-dev-env.sh has been executed first
check_prerequisites() {
  local missing=false
  local missing_reasons=()

  if [ ! -f "$HOME/.bashrc" ]; then
    missing=true
    missing_reasons+=("~/.bashrc configuration file has not been deployed.")
  fi

  if ! command -v git >/dev/null 2>&1; then
    missing=true
    missing_reasons+=("Core 'git' CLI tool is missing.")
  fi

  if [ "$missing" = true ]; then
    echo ""
    echo "======================================================================"
    echo "⚠️ Prerequisite Warning: Base environment setup has not been run!"
    echo "======================================================================"
    for reason in "${missing_reasons[@]}"; do
      echo "   • $reason"
    done
    echo "👉 It is strongly recommended to run './install-dev-env.sh' first"
    echo "   to bootstrap your shell, editors, and base developer tools."
    echo "======================================================================"

    if [ -t 0 ]; then
      read -rp "Do you want to proceed with setting up local services anyway? (y/N) " confirm_proceed
      if [[ ! "$confirm_proceed" =~ ^[Yy]$ ]]; then
        echo "Exiting. Please run './install-dev-env.sh' first."
        exit 1
      fi
    fi
  else
    echo "   ✓ Base developer environment prerequisites detected."
  fi
}

check_prerequisites

# 2. Package Installation Functions
install_arch_deps() {
  echo "==> Updating pacman databases and installing local service packages"
  sudo pacman -Sy --noconfirm

  local PACKAGES=(
    podman
    podman-compose
    podman-docker
    mkcert
    just
    nss
    curl
    jq
  )

  local TO_INSTALL=()
  for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
      TO_INSTALL+=("$pkg")
    fi
  done

  if [ ${#TO_INSTALL[@]} -ne 0 ]; then
    echo "==> Installing Arch packages: ${TO_INSTALL[*]}"
    sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}"
  else
    echo "==> All Arch packages for local services are already installed."
  fi
}

install_debian_deps() {
  echo "==> Updating apt databases and installing local service packages"
  sudo apt-get update -y

  local PACKAGES=(
    podman
    podman-compose
    mkcert
    just
    libnss3-tools
    curl
    jq
  )

  local TO_INSTALL=()
  for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      TO_INSTALL+=("$pkg")
    fi
  done

  if [ ${#TO_INSTALL[@]} -ne 0 ]; then
    echo "==> Installing Debian/Ubuntu packages: ${TO_INSTALL[*]}"
    sudo apt-get install -y "${TO_INSTALL[@]}"
  else
    echo "==> All Debian packages for local services are already installed."
  fi

  # Fallback for podman-docker package if missing
  if ! dpkg -s podman-docker >/dev/null 2>&1; then
    sudo apt-get install -y podman-docker || true
  fi
}

install_macos_deps() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Error: Homebrew is required on macOS. Please run ./install-dev-env.sh first." >&2
    exit 1
  fi

  local PACKAGES=(
    podman
    podman-compose
    mkcert
    just
    nss
    curl
    jq
  )

  local TO_INSTALL=()
  for pkg in "${PACKAGES[@]}"; do
    if ! brew list --formula "$pkg" >/dev/null 2>&1; then
      TO_INSTALL+=("$pkg")
    fi
  done

  if [ ${#TO_INSTALL[@]} -ne 0 ]; then
    echo "==> Installing Homebrew packages: ${TO_INSTALL[*]}"
    brew install "${TO_INSTALL[@]}"
  else
    echo "==> All Homebrew packages for local services are already installed."
  fi

  # Initialize and start Podman Machine on macOS if not already running
  if ! podman machine list 2>/dev/null | grep -q "Running"; then
    echo "==> Setting up Podman Machine on macOS"
    if ! podman machine list 2>/dev/null | grep -q "podman-machine-default"; then
      podman machine init
    fi
    podman machine start
  fi
}

# Run platform package installer
if [ "$OS_FAMILY" = "arch" ]; then
  install_arch_deps
elif [ "$OS_FAMILY" = "debian" ]; then
  install_debian_deps
elif [ "$OS_FAMILY" = "macos" ]; then
  install_macos_deps
fi

# 3. Configure Rootless Podman Socket & Auto-Update Timer (Linux / WSL)
PODMAN_SOCK=""
if [ "$OS_FAMILY" != "macos" ]; then
  echo "==> Enabling and starting user-level Podman systemd socket & auto-update timer"
  systemctl --user enable --now podman.socket || true
  systemctl --user enable --now podman-auto-update.timer || true

  # Allow rootless Podman containers to bind ports 80 and 443 without root
  if command -v sysctl >/dev/null 2>&1; then
    sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80 >/dev/null 2>&1 || true
  fi

  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  PODMAN_SOCK="$XDG_RUNTIME_DIR/podman/podman.sock"

  if [ -S "$PODMAN_SOCK" ]; then
    echo "   ✓ Podman rootless API socket active at $PODMAN_SOCK"
  else
    echo "⚠️ Warning: Podman socket at $PODMAN_SOCK not found yet. Traefik will attempt default connection."
  fi
else
  # macOS Podman Machine socket
  PODMAN_SOCK="$HOME/.local/share/containers/podman/machine/qemu/podman.sock"
fi

# 4. Setup Local Services Directory (~/.local/share/local-services)
SERVICE_DIR="$HOME/.local/share/local-services"
CERTS_DIR="$SERVICE_DIR/certs"
TRAEFIK_DIR="$SERVICE_DIR/traefik"

mkdir -p "$CERTS_DIR" "$TRAEFIK_DIR"

# 5. Initialize mkcert Root CA & Generate Wildcard Certificates for *.localhost
echo "==> Setting up mkcert local CA and certificates"
mkcert -install

CERT_FILE="$CERTS_DIR/local-cert.pem"
KEY_FILE="$CERTS_DIR/local-key.pem"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
  echo "==> Generating wildcard SSL certificate for *.localhost"
  mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" "*.localhost" "localhost" "127.0.0.1" "::1"
  echo "   ✓ Certificate generated successfully!"
else
  echo "   ✓ SSL certificates already exist at $CERTS_DIR"
fi

# 6. Deploy Traefik v3 Dynamic SSL Configuration
TRAEFIK_DYNAMIC_CFG="$TRAEFIK_DIR/dynamic.yml"
echo "==> Deploying Traefik v3 dynamic TLS configuration"
cat <<EOF > "$TRAEFIK_DYNAMIC_CFG"
tls:
  certificates:
    - certFile: /certs/local-cert.pem
      keyFile: /certs/local-key.pem
  stores:
    default:
      defaultCertificate:
        certFile: /certs/local-cert.pem
        keyFile: /certs/local-key.pem
EOF

# 7. Deploy Docker Compose Stack (Traefik v3 + BentoPDF + MCP Containers)
COMPOSE_FILE="$SERVICE_DIR/docker-compose.yml"
echo "==> Deploying Docker Compose stack ($COMPOSE_FILE)"

DOCKER_SOCK_MOUNT="${PODMAN_SOCK}:/var/run/docker.sock:ro"
if [ "$OS_FAMILY" = "macos" ]; then
  DOCKER_SOCK_MOUNT="$HOME/.local/share/containers/podman/machine/qemu/podman.sock:/var/run/docker.sock:ro"
fi

cat <<EOF > "$COMPOSE_FILE"
version: '3.8'

networks:
  local-mesh:
    driver: bridge

services:
  # 🚦 Traefik v3 Ingress Reverse Proxy
  traefik:
    image: traefik:v3.0
    container_name: traefik-ingress
    restart: unless-stopped
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.file.filename=/etc/traefik/dynamic.yml"
      - "--providers.file.watch=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"       # Standard HTTP (http://app.localhost - no port number needed!)
      - "443:443"     # Standard HTTPS (https://app.localhost - no port number needed!)
      - "8088:8080"   # Traefik Dashboard (http://traefik.localhost:8088 or http://traefik.localhost)
    volumes:
      - "${DOCKER_SOCK_MOUNT}"
      - "${CERTS_DIR}:/certs:ro"
      - "${TRAEFIK_DYNAMIC_CFG}:/etc/traefik/dynamic.yml:ro"
    networks:
      - local-mesh
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`traefik.localhost\`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "io.containers.autoupdate=registry"

  # 📄 BentoPDF - Privacy-First Local PDF Toolkit UI
  bentopdf:
    image: ghcr.io/alam00000/bentopdf-simple:latest
    container_name: bentopdf
    restart: unless-stopped
    networks:
      - local-mesh
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bentopdf.rule=Host(\`pdf.localhost\`)"
      - "traefik.http.routers.bentopdf.entrypoints=web,websecure"
      - "traefik.http.routers.bentopdf.tls=true"
      - "traefik.http.services.bentopdf.loadbalancer.server.port=8080"
      - "io.containers.autoupdate=registry"

  # 🌐 Puppeteer MCP Server (Containerized Browser Agent for Hermes)
  mcp-puppeteer:
    image: mcp/puppeteer:latest
    container_name: mcp-puppeteer
    restart: unless-stopped
    environment:
      - PORT=3000
    networks:
      - local-mesh
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mcp-puppeteer.rule=Host(\`puppeteer.mcp.localhost\`)"
      - "traefik.http.routers.mcp-puppeteer.entrypoints=web,websecure"
      - "traefik.http.routers.mcp-puppeteer.tls=true"
      - "traefik.http.services.mcp-puppeteer.loadbalancer.server.port=3000"
      - "io.containers.autoupdate=registry"

  # 🐘 PostgreSQL Database (Local Dev Storage for OpenCode)
  local-postgres:
    image: postgres:16-alpine
    container_name: local-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: devuser
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: devdb
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - local-mesh
    ports:
      - "5432:5432"

volumes:
  postgres-data:
EOF

# 8. Deploy Justfile for Task Runner Control
JUSTFILE="$SERVICE_DIR/justfile"
echo "==> Deploying Justfile task manager ($JUSTFILE)"

cat <<'EOF' > "$JUSTFILE"
# ==============================================================================
# Justfile - Local Service Mesh Manager
# Usage: just -f ~/.local/share/local-services/justfile <command>
# ==============================================================================

default:
    @just --list -f {{justfile()}}

# Start all local container services via podman-compose
up:
    @echo "==> Starting local container mesh..."
    podman-compose -f {{justfile_directory()}}/docker-compose.yml up -d

# Stop all local container services
down:
    @echo "==> Stopping local container mesh..."
    podman-compose -f {{justfile_directory()}}/docker-compose.yml down

# View status of running containers
status:
    @echo "==> Service Status:"
    podman-compose -f {{justfile_directory()}}/docker-compose.yml ps

# View container logs (optional service name: just logs bentopdf)
logs service="":
    podman-compose -f {{justfile_directory()}}/docker-compose.yml logs -f {{service}}

# Restart all local container services
restart: down up

# Run Podman auto-update on tagged containers
update:
    @echo "==> Running Podman auto-update for tagged container services..."
    podman auto-update

# Regenerate mkcert SSL certificates
certs:
    @echo "==> Regenerating SSL certificates..."
    mkcert -cert-file {{justfile_directory()}}/certs/local-cert.pem -key-file {{justfile_directory()}}/certs/local-key.pem "*.localhost" "localhost" "127.0.0.1"

# Output OpenCode & Hermes MCP config snippets
mcp-info:
    @echo "======================================================================"
    @echo "👉 OpenCode Remote MCP Configuration (~/.config/opencode/opencode.json):"
    @echo '  "mcp": {'
    @echo '    "puppeteer": {'
    @echo '      "type": "remote",'
    @echo '      "url": "http://puppeteer.mcp.localhost/sse",'
    @echo '      "enabled": true'
    @echo '    }'
    @echo '  }'
    @echo "======================================================================"
    @echo "👉 Hermes Agent Remote MCP Configuration (~/.hermes/config.yaml):"
    @echo 'mcp_servers:'
    @echo '  puppeteer:'
    @echo '    url: "http://puppeteer.mcp.localhost/sse"'
    @echo '    transport: "sse"'
    @echo "======================================================================"
EOF

# 9. Add Shell Alias to ~/.bashrc for quick control (`jl`)
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ]; then
  if ! grep -q "alias jl=" "$BASHRC" 2>/dev/null; then
    echo "==> Adding 'jl' alias to ~/.bashrc"
    cat <<'EOF' >> "$BASHRC"

# Local Service Mesh Alias (just task runner)
alias jl='just -f ~/.local/share/local-services/justfile'
EOF
  fi
fi

# 9.5. Smart Update of OpenCode & Hermes MCP Configurations
# Updates heavy/browser MCPs (puppeteer) to point to containerized Traefik services
OPENCODE_CFG="$HOME/.config/opencode/opencode.json"
if [ -f "$OPENCODE_CFG" ]; then
  echo "==> Updating OpenCode MCP config to connect to containerized Puppeteer MCP service"
  mkdir -p "$HOME/.config/opencode"
  cat <<'EOF' > "$OPENCODE_CFG"
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "."],
      "enabled": true
    },
    "git": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-git"],
      "enabled": true
    },
    "puppeteer": {
      "type": "remote",
      "url": "http://puppeteer.mcp.localhost/sse",
      "enabled": true
    },
    "postgres": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-postgres"],
      "enabled": true
    }
  }
}
EOF
fi

HERMES_CFG="$HOME/.hermes/config.yaml"
if [ -f "$HERMES_CFG" ] || [ -d "$HOME/.hermes" ]; then
  echo "==> Updating Hermes Agent MCP config to connect to containerized Puppeteer MCP service"
  mkdir -p "$HOME/.hermes"
  cat <<'EOF' > "$HERMES_CFG"
mcp_servers:
  puppeteer:
    url: "http://puppeteer.mcp.localhost/sse"
    transport: "sse"
  fetch:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-fetch"]
  github:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-github"]
EOF
fi

# 10. Start Local Container Stack
echo "==> Starting local container mesh via podman-compose"
podman-compose -f "$COMPOSE_FILE" up -d || true

echo ""
echo "======================================================================"
echo "🎉 Local Services setup complete!"
echo "======================================================================"
echo "👉 Web Services Available (No port numbers required!):"
echo "   • BentoPDF Toolkit UI: https://pdf.localhost (or http://pdf.localhost)"
echo "   • Traefik Dashboard:   http://traefik.localhost:8088"
echo "   • Puppeteer MCP:       http://puppeteer.mcp.localhost"
echo "   • Postgres Database:   localhost:5432 (user: devuser, pass: devpassword, db: devdb)"
echo ""
echo "👉 Quick Control Commands (using 'jl' alias after 'exec bash'):"
echo "   • jl status   - Check status of containers"
echo "   • jl logs     - View real-time service logs"
echo "   • jl restart  - Restart all container services"
echo "   • jl mcp-info - Display OpenCode & Hermes connection configs"
echo "======================================================================"

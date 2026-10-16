# 🚦 Local Services & Rootless Container Mesh Guide

**Target Runtime**: Rootless Podman & Podman Compose  
**Reverse Proxy**: Traefik v3 with dynamic SSL  
**Task Runner**: `just` (aliased as `jl`)  
**Security & Trust**: Local wildcard TLS via `mkcert` (`*.localhost`)  

---

## 🏛️ 1. Architecture Overview

The local services mesh provides a local, privacy-respecting development infrastructure running completely in **rootless user space**. Web applications and developer tools are mapped to clean `.localhost` subdomains with valid TLS/SSL certificates, eliminating the need to memorize custom port numbers.

```mermaid
flowchart TD
    Browser["Web Browser (Windows or Linux)"]
    DevClients["Dev Clients (psql, DBeaver, curl)"]
    Agents["AI Agents (OpenCode, Hermes, Claude)"]

    subgraph HostPorts["Host Port Bindings"]
        P80["Port 80 (HTTP)"]
        P443["Port 443 (HTTPS)"]
        P8088["Port 8088 (Dashboard)"]
        P5432["Port 5432 (Postgres)"]
    end

    subgraph Traefik["Traefik v3 Ingress (Rootless Container)"]
        RouterHTTP["HTTP -> HTTPS Redirect (80 -> 443)"]
        TLSTerm["TLS Termination (*.localhost)"]
        DockerProv["Podman Engine Socket Provider"]
        FileProv["Dynamic File Provider (/certs/local-cert.pem)"]
    end

    subgraph Mesh["Local Mesh Network (local-mesh)"]
        Bento["BentoPDF (pdf.localhost)"]
        Postgres["PostgreSQL 16 (local-postgres:5432)"]
    end

    subgraph OnDemand["On-Demand Agent Tooling"]
        PuppeteerMCP["Puppeteer MCP (podman run --rm -i ... stdio)"]
    end

    Browser -->|HTTP/HTTPS| P80 & P443
    DevClients -->|Direct TCP| P5432
    Agents -->|stdio I/O| PuppeteerMCP
    Agents -->|psql / TCP| P5432

    P80 --> RouterHTTP
    P443 --> TLSTerm
    RouterHTTP --> TLSTerm
    TLSTerm --> Bento
    P5432 --> Postgres
```

---

## 🌐 2. Active Services & Endpoints

| Service | Local Domain / URL | Profile | Port Binding | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **BentoPDF Web UI** | `https://pdf.localhost` | Default | 80/443 | Privacy-first PDF merger, split, OCR, and editor |
| **Traefik Dashboard** | `https://traefik.localhost/dashboard/` | Default | 80/443 & `localhost:8088` | Real-time reverse proxy routing & health metrics |
| **PostgreSQL Database** | `localhost:5432` | Default | `0.0.0.0:5432` | Local dev database (`devuser` / `devpassword` / `devdb`) |
| **Ollama Local LLM** | `https://ollama.localhost` | `llm` | `0.0.0.0:11434` | Offline LLM inference engine & OpenAI API endpoint |
| **Open WebUI** | `https://chat.localhost` | `llm` / `webui` | 80/443 (internal 8080) | ChatGPT-style browser chat UI for Ollama & cloud LLMs |
| **Kavita Reader** | `https://kavita.localhost` | `books` / `apps` | 80/443 (internal 5000) | E-book, comic, and manga reader UI (mounts `$HOME/Books`) |
| **Plex Media Server** | `https://plex.localhost` | `media` | `0.0.0.0:32400` | Local media streaming server (mounts `$HOME/Media`) |
| **Puppeteer MCP** | Stdio (On-demand) | Agent Tool | None (zero idle RAM) | Headless Chromium web scraping for AI agents |

> [!TIP]
> All HTTP requests (e.g. `http://pdf.localhost`, `http://ollama.localhost`, `http://chat.localhost`) automatically redirect to HTTPS with valid TLS certificates.

---

## ⚡ 3. Managing Services with the Task Runner (`jl`)

The task runner [`local-services/justfile`](../local-services/justfile) is linked to `~/.local/share/local-services/justfile` and aliased to **`jl`** in your shell.

| Command | Action |
| :--- | :--- |
| `jl status` | View container health, IDs, and mapped ports |
| `jl up` | Start default core container mesh (Traefik, BentoPDF, PostgreSQL) |
| `jl down` | Stop all containers without deleting data volumes |
| `jl restart` | Quick restart of the entire mesh |
| `jl logs` | Follow aggregate logs from all mesh containers |
| `jl logs <service>` | Follow logs for a specific service (e.g., `jl logs bentopdf`) |
| `jl certs` | Regenerate local wildcard SSL certificates via `mkcert` |
| `jl update` | Pull updated images for containers tagged `io.containers.autoupdate` |
| `jl mcp-info` | Display configuration snippets for OpenCode & Hermes |
| `jl up-llm` | Start Ollama service on `https://ollama.localhost` and port 11434 |
| `jl down-llm` | Stop Ollama container |
| `jl up-webui` | Start Open WebUI at `https://chat.localhost` (auto-starts Ollama) |
| `jl down-webui` | Stop Open WebUI container |
| `jl llm-pull <model>` | Download an LLM model into Ollama (e.g., `jl llm-pull qwen2.5-coder:7b`) |
| `jl llm-run <model>` | Start interactive terminal chat with an Ollama model |
| `jl llm-list` | List downloaded local models in Ollama |
| `jl llm-status` | Display available models and size via local API |
| `jl up-books` | Start Kavita e-book and manga reader (`https://kavita.localhost`) |
| `jl down-books` | Stop Kavita container |
| `jl up-media` | Start Plex media server (`https://plex.localhost`) |
| `jl down-media` | Stop Plex container |
| `jl up-all` | Start ALL services (core + LLM + WebUI + books + media) |


---

## 🐘 4. Using the Local PostgreSQL Database

The stack runs PostgreSQL 16 Alpine with persistent data stored in Podman volume `local-services_postgres-data`.

### Credentials
* **Host**: `localhost` (or `127.0.0.1`)
* **Port**: `5432`
* **Username**: `devuser`
* **Password**: `devpassword`
* **Database**: `devdb`
* **Connection String**: `postgresql://devuser:devpassword@localhost:5432/devdb`

### Connecting via Native Host CLI (`psql`)
The `psql` client is included in your global Nix environment (`home/packages.nix`):
```bash
PGPASSWORD=devpassword psql -h localhost -U devuser -d devdb
```

### Connecting via Container Shell
```bash
podman exec -it local-postgres psql -U devuser -d devdb
```

### Quick One-Line Health Check
```bash
podman exec local-postgres psql -U devuser -d devdb -c "SELECT version();"
```

---

## 🤖 5. Using Puppeteer MCP for AI Agents

Rather than running an idle Chromium browser container continuously in the background, Puppeteer MCP executes **on-demand** over stdio.

### OpenCode Configuration (`~/.config/opencode/opencode.json`)
```json
{
  "mcp": {
    "puppeteer": {
      "type": "local",
      "command": [
        "podman",
        "run",
        "-i",
        "--rm",
        "--init",
        "docker.io/mcp/puppeteer:latest"
      ]
    }
  }
}
```

### Hermes Agent Configuration (`~/.hermes/config.yaml`)
```yaml
mcp_servers:
  puppeteer:
    command: podman
    args: ["run", "-i", "--rm", "--init", "docker.io/mcp/puppeteer:latest"]
```

### Verifying Puppeteer MCP Functionality
Run this one-liner to verify the containerized MCP engine responds to JSON-RPC initialization:
```bash
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}' | podman run --rm -i docker.io/mcp/puppeteer:latest
```

---

## 🦙 6. Using the Ollama Local LLM Inference Engine

The local inference engine runs under the `llm` profile so it only consumes RAM and GPU compute when you explicitly launch it.

> [!TIP]
> **Complete Dedicated Guide**: See [docs/ollama-guide.md](ollama-guide.md) for detailed terminal chat workflows, Open WebUI browser setup, OpenAI-compatible REST API examples, and model sizing tiers.

### Headless REST API vs. Web Interface
When accessing `https://ollama.localhost` or `http://localhost:11434`, Ollama returns plain text: `"Ollama is running"`. This is normal — Ollama is a headless backend engine designed for CLI interaction, agent tooling, and API requests.

### Lifecycle Management
```bash
jl up-llm       # Start Ollama on https://ollama.localhost and port 11434
jl status       # Verify container health and port bindings
jl down-llm     # Stop Ollama and release host memory
```

### Native Host CLI & Interactive Chat
A transparent wrapper function in `~/.bashrc` delegates `ollama` commands from your host shell directly into the container:
```bash
# Pull a fast coding model:
ollama pull qwen2.5-coder:1.5b    # or: jl llm-pull qwen2.5-coder:1.5b

# Start an interactive terminal chat REPL:
ollama run qwen2.5-coder:1.5b     # or: jl llm-run qwen2.5-coder:1.5b

# Check active models in RAM and disk:
ollama ps
ollama list                       # or: jl llm-list
```

### Connecting AI Agents to Local Ollama
Ollama exposes an OpenAI-compatible API at `http://localhost:11434/v1` and `https://ollama.localhost/v1`.

Enable local inference in `~/.bashrc.local`:
```bash
export OPENAI_BASE_URL="http://localhost:11434/v1"
export OPENAI_API_KEY="ollama"
```

In OpenCode:
```bash
oc --model qwen2.5-coder:1.5b
```


---

## 📚 7. Homelab On-Demand Services (Kavita & Plex)

Homelab services are isolated under the `books` and `media` profiles so they do not consume resources during daily coding sessions:

### Kavita E-Book & Manga Reader
* **Web UI**: [https://kavita.localhost](https://kavita.localhost)
* **Library Directory**: `${BOOKS_DIR:-$HOME/Books}`
```bash
jl up-books     # Start Kavita service
jl down-books   # Stop Kavita service
```

### Plex Media Server
* **Web UI**: [https://plex.localhost](https://plex.localhost) or `http://localhost:32400/web`
* **Media Directory**: `${MEDIA_DIR:-$HOME/Media}`
```bash
jl up-media     # Start Plex service
jl down-media   # Stop Plex service
```

---

## ➕ 8. How to Add a New Service to the Mesh (Step-by-Step)

Adding custom developer tools or services (such as Redis, pgAdmin, MailHog, or custom web APIs) is fully declarative and repeatable.

### Example: Adding `pgAdmin` or `Redis`

#### Step 1: Add the Service to `local-services/docker-compose.yml`
Open [`local-services/docker-compose.yml`](file:///home/tonyh/_Projects/setup-linux-scripts/local-services/docker-compose.yml) and declare the service:

```yaml
  # 📊 pgAdmin 4 - Web UI for PostgreSQL
  pgadmin:
    image: docker.io/dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: dev@localhost
      PGADMIN_DEFAULT_PASSWORD: devpassword
    networks:
      - local-mesh
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pgadmin.rule=Host(`pgadmin.localhost`)"
      - "traefik.http.routers.pgadmin.entrypoints=web,websecure"
      - "traefik.http.routers.pgadmin.tls=true"
      - "traefik.http.services.pgadmin.loadbalancer.server.port=80"
```

#### Step 2: Include Subdomain in Wildcard Certificate (if necessary)
While `*.localhost` covers single-level subdomains, explicitly adding the subdomain ensures compatibility with all browsers and curl:
1. Open [`local-services/justfile`](file:///home/tonyh/_Projects/setup-linux-scripts/local-services/justfile) and add the new subdomain to the `certs` recipe:
   ```just
   mkcert -cert-file {{justfile_directory()}}/certs/local-cert.pem -key-file {{justfile_directory()}}/certs/local-key.pem "*.localhost" "localhost" "pdf.localhost" "traefik.localhost" "pgadmin.localhost" "127.0.0.1" "::1"
   ```
2. Run `jl certs`.

#### Step 3: Apply Declarative Changes & Deploy
Because `~/.local/share/local-services/` is managed declaratively by Home Manager, run `./bootstrap.sh` (or `jl restart` if running from repo clone):
```bash
jl up
```

#### Step 4: Access Your New Service
Navigate directly to [https://pgadmin.localhost](https://pgadmin.localhost) in your browser!

---

## 🔧 9. Troubleshooting & Maintenance

### Port 80 / 443 Permission Denied on Reboot
If WSL restarts and Traefik fails to start with:
`rootlessport cannot expose privileged port 80`

**Fix**:
Make sure `/etc/sysctl.d/99-podman-ports.conf` exists:
```bash
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-podman-ports.conf && sudo sysctl --system
jl up
```

### Windows Browser Reports "Certificate Authority Invalid"
**Fix**:
Import the WSL Root CA into the Windows Trusted Root store once using **Administrator PowerShell**:
```powershell
Import-Certificate -FilePath "\\wsl.localhost\Ubuntu-24.04\home\tonyh\.local\share\mkcert\rootCA.pem" -CertStoreLocation Cert:\LocalMachine\Root
```
*(Replace `Ubuntu-24.04` with your distro name if running on a different distribution).*

### Resolving `.localhost` Subdomains
Under modern Windows, macOS, and Linux systemd-resolved, all `*.localhost` domains automatically resolve to loopback `127.0.0.1` without needing `/etc/hosts` modifications.
If your local Linux resolver does not resolve subdomains, you can add them to `/etc/hosts`:
```
127.0.0.1 pdf.localhost traefik.localhost pgadmin.localhost
```

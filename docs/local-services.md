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

| Service | Local Domain / URL | Port Binding | Purpose |
| :--- | :--- | :--- | :--- |
| **BentoPDF Web UI** | `https://pdf.localhost` | Route via Traefik (80/443) | Privacy-first PDF merger, split, OCR, and editor |
| **Traefik Dashboard** | `https://traefik.localhost/dashboard/` | 80/443 & `localhost:8088` | Real-time reverse proxy routing & health metrics |
| **PostgreSQL Database** | `localhost:5432` | `0.0.0.0:5432` | Local dev database (`devuser` / `devpassword` / `devdb`) |
| **Puppeteer MCP** | Stdio (On-demand) | None (zero idle RAM) | Headless Chromium web scraping for AI agents |

> [!TIP]
> All HTTP requests (e.g. `http://pdf.localhost`) automatically redirect to HTTPS with valid TLS certificates.

---

## ⚡ 3. Managing Services with the Task Runner (`jl`)

The task runner [`local-services/justfile`](file:///home/tonyh/_Projects/setup-linux-scripts/local-services/justfile) is installed to `~/.local/share/local-services/justfile` and aliased to **`jl`** in your shell.

| Command | Action |
| :--- | :--- |
| `jl status` | View container health, IDs, and mapped ports |
| `jl up` | Start or converge all services in background (`-d`) |
| `jl down` | Stop all containers without deleting data volumes |
| `jl restart` | Quick restart of the entire mesh |
| `jl logs` | Follow aggregate logs from all mesh containers |
| `jl logs <service>` | Follow logs for a specific service (e.g., `jl logs bentopdf`) |
| `jl certs` | Regenerate local wildcard SSL certificates via `mkcert` |
| `jl update` | Pull updated images for containers tagged `io.containers.autoupdate` |
| `jl mcp-info` | Display configuration snippets for OpenCode & Hermes |

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

## ➕ 6. How to Add a New Service to the Mesh (Step-by-Step)

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

#### Step 3: Sync to Live Directory & Deploy
Deploy the changes:
```bash
cp -f local-services/docker-compose.yml local-services/justfile ~/.local/share/local-services/
jl up
```

#### Step 4: Access Your New Service
Navigate directly to [https://pgadmin.localhost](https://pgadmin.localhost) in your browser!

---

## 🔧 7. Troubleshooting & Maintenance

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

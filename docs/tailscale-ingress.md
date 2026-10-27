# 🌐 Tailscale Private Mesh Ingress Guide

This guide details the architecture, setup, and day-to-day operation of the **Tailscale Private Mesh Ingress** for your containerized developer services.

It allows you to securely access your laptop's local microservices (like **BentoPDF**, **Open WebUI**, **Ollama**, and **Traefik**) from your iPhone, iPad, or secondary computer from anywhere in the world—**without port forwarding, opening firewall ports, or exposing services to the public internet**.

---

## 🏗️ Architecture & Security Model

```mermaid
flowchart LR
    subgraph AppleDevice["📱 Remote Client (iPhone / Laptop)"]
        Safari["Browser / Web App"]
    end

    subgraph TailscaleMesh["🔒 Tailscale WireGuard Private Mesh (komodo-sole.ts.net)"]
        TSEncrypt["Tailscale End-to-End Encryption"]
    end

    subgraph LaptopHost["💻 Host Laptop (WSL2 / Linux)"]
        subgraph PodmanNetwork["Podman Rootless Bridge (local-mesh)"]
            TS_PDF["local-tailscale-pdf\n(pdf-<machine>.komodo-sole.ts.net)"]
            TS_CHAT["local-tailscale-chat\n(chat-<machine>.komodo-sole.ts.net)"]
            TS_TRAEFIK["local-tailscale-traefik\n(traefik-<machine>.komodo-sole.ts.net)"]
            TS_OLLAMA["local-tailscale-ollama\n(ollama-<machine>.komodo-sole.ts.net)"]
            TS_BOOKS["local-tailscale-books\n(books-<machine>.komodo-sole.ts.net)"]

            BentoPDF["bentopdf:8080"]
            WebUI["local-open-webui:8080"]
            Traefik["traefik-ingress:8080"]
            Ollama["local-ollama:11434"]
            Kavita["local-kavita:5000"]
        end
    end

    Safari -->|Port 443 HTTPS| TSEncrypt
    TSEncrypt --> TS_PDF --> BentoPDF
    TSEncrypt --> TS_CHAT --> WebUI
    TSEncrypt --> TS_TRAEFIK --> Traefik
    TSEncrypt --> TS_OLLAMA --> Ollama
    TSEncrypt --> TS_BOOKS --> Kavita
```

### Key Architectural Strengths:
1. **Dedicated Port 443 HTTPS Endpoints:** Each service gets its own friendly MagicDNS name. No custom port numbers (like `:8443` or `:5000`) are required in your browser.
2. **Automated Official TLS Certificates:** Tailscale automatically issues and renews real Let's Encrypt certificates for each node. Your mobile browser shows a secure padlock with zero certificate warnings.
3. **Userspace Rootless Isolation:** Tailscale runs inside rootless Podman containers (`TS_USERSPACE=true`). It does not modify your host kernel routing tables or require root/sudo privileges.
4. **Preserved Local Workflow:** Your local laptop workflow remains 100% untouched. On your laptop, you continue using fast local loopback URLs (`https://pdf.localhost`, `https://chat.localhost`).

---

## 🔗 Dedicated Remote Endpoints Matrix

Each service is mapped to a dedicated hostname on standard **HTTPS Port 443**:

| Service | Remote Tailnet URL (iPhone / Remote) | Local Laptop URL | Description |
| :--- | :--- | :--- | :--- |
| **BentoPDF** | `https://pdf-<machine>.komodo-sole.ts.net` | `https://pdf.localhost` | Privacy-first PDF manipulation suite |
| **Open WebUI** | `https://chat-<machine>.komodo-sole.ts.net` | `https://chat.localhost` | Local ChatGPT-style AI chat interface |
| **Traefik Dashboard** | `https://traefik-<machine>.komodo-sole.ts.net` | `http://localhost:8088` | Container proxy routing & health monitor |
| **Ollama API** | `https://ollama-<machine>.komodo-sole.ts.net` | `https://ollama.localhost` | Local LLM inference engine REST API |
| **Kavita** | `https://books-<machine>.komodo-sole.ts.net` | `https://kavita.localhost` | E-book, manga, and comic server |

*(Replace `<machine>` with your machine identifier, e.g. `asus`, `thinkpad`, `envy`).*

---

## ⚙️ Multi-Machine Parameterization (`TS_MACHINE_ID`)

When deploying across multiple laptops (e.g. an Asus ROG Zephyrus, an HP Envy, or a ThinkPad), the machine identifier is **fully parameterized** so services never collide on your Tailnet.

### How it Resolves:
1. **Environment Configuration (`.env`):**
   The compose stack checks `~/.local/share/local-services/.env`:
   ```bash
   # Machine identifier for Tailnet hostnames
   TS_MACHINE_ID=asus
   TS_AUTHKEY=tskey-auth-...
   ```
2. **Automatic Detection (`bootstrap.sh`):**
   When running `./bootstrap.sh` on a new laptop, if `.env` does not exist, the script automatically reads the machine's hostname (e.g., `ThinkPadX1`, `DellXPS`), sanitizes it to lowercase (`thinkpad`, `dell`), and scaffolds `.env` automatically.
3. **Dynamic Introspection (`jl remote-info`):**
   The `jl remote-info` task inspects the running Tailscale nodes via JSON API, automatically displaying the exact URLs for whichever machine is active.

---

## 🚀 Setup & Activation Workflow

### Step 1: Generate a Reusable Auth Key
1. Go to your [Tailscale Keys Console](https://login.tailscale.com/admin/settings/keys).
2. Click **Generate auth key...**.
3. Enable **Reusable** (and optionally **Ephemeral** so test containers clean up if deleted).
4. Copy the generated key (`tskey-auth-...`).

### Step 2: Configure `.env`
Save your key in `~/.local/share/local-services/.env`:
```bash
TS_MACHINE_ID=asus
TS_AUTHKEY=tskey-auth-kv8sKGeLeT11CNTRL-...
```
*(Permissions are restricted to `600` so only your user can read it).*

### Step 3: Enable HTTPS in Tailscale Admin Console
1. Open your [Tailscale DNS Settings](https://login.tailscale.com/admin/dns).
2. Under **HTTPS Certificates**, ensure **Enable HTTPS Certificates** is turned **ON**.

### Step 4: Start the Remote Ingress Mesh
Run the task runner command:
```bash
jl up-remote
```

All 5 dedicated Tailscale containers will spin up, authenticate with your key, request official TLS certificates, and start routing.

---

## 🛠️ Management & Verification Commands

All remote mesh tasks are run via the `jl` (`just -f ...`) shorthand:

```bash
# Start all remote Tailscale ingress nodes
jl up-remote

# View active HTTPS endpoints and Tailnet domain
jl remote-info

# Check connection status of all 5 dedicated nodes
jl remote-status

# Show login link if a node is waiting for authorization
jl remote-auth

# Stop all remote Tailscale ingress nodes
jl down-remote
```

---

## ❓ Frequently Asked Questions & Troubleshooting

### Q: Why does `https://` work, but plain `http://` fail?
Tailscale Serve strictly enforces TLS on Port 443 for MagicDNS hostnames. Plain unencrypted HTTP is refused by Tailscale to prevent unencrypted traffic over the mesh. Always access your endpoints using **`https://`**.

### Q: Why does my iPhone show "Cannot find server" right after deployment?
iOS aggressively caches DNS. After deploying new hostnames (like `pdf-asus`), open the **Tailscale app on your iPhone**, toggle the VPN **Disconnect** and **Reconnect** once. This forces iOS to reload MagicDNS records.

### Q: Why does `ping 100.x.y.z` from host bash show 100% packet loss?
1. **Userspace Networking:** Tailscale runs inside containers in userspace mode (`TS_USERSPACE=true`). It deliberately does not inject routes into your WSL2 host routing table.
2. **Apple iOS Security:** iOS drops standard ICMP ping packets by default.
To ping an iPhone or other Tailnet node from your laptop, use Tailscale's WireGuard ping:
```bash
podman exec local-tailscale-pdf tailscale ping <ip-or-host>
```

### Q: Can I open `https://pdf-asus.komodo-sole.ts.net` from this PC's browser?
Your PC's web browser uses your local Wi-Fi router's DNS, which cannot resolve private `.ts.net` domains unless the native Windows Tailscale desktop client is running.
On your laptop itself, always use your fast, zero-latency local URLs:
* **BentoPDF:** `https://pdf.localhost`
* **Open WebUI:** `https://chat.localhost`
* **Traefik:** `http://localhost:8088`

---

## 🔮 Roadmap: Automated Auth Key Rotator (OAuth-Driven)

> [!NOTE]
> **Inspiration**: [How I Built a Tailscale Auth Key Rotator by Brent Gruber](https://medium.com/@brent.gruber77/how-i-built-a-tailscale-auth-key-rotator-814722b839e0)

### The Problem with Static Auth Keys
* Manual Tailscale auth keys have a strict **maximum lifespan of 90 days**.
* When an auth key expires, fresh machine bootstrapping or container recreation silently fails.
* Personal API access tokens are overly broad (granting full administrative control over the entire Tailnet).

### Proposed Architecture & Automation Pipeline

```mermaid
flowchart TD
    subgraph OAuth["🔐 Tailscale Control Plane"]
        OC["Scoped OAuth Client\n(keys:write)"]
        API["Tailscale Token Endpoint\n(/api/v2/oauth/token)"]
        KeyGen["Key Generator\n(/api/v2/tailnet/{tailnet}/keys)"]
    end

    subgraph HostSystem["💻 Workstation / CI Machine"]
        Timer["systemd user timer\n(Runs every 30 days)"]
        Script["rotate-ts-key script\n(or 'jl rotate-auth-key')"]
        SecretStore["Secret Store\n(~/.local/share/local-services/.env or SOPS)"]
        Containers["Podman Tailscale Sidecars\n(local-tailscale-*)"]
    end

    Timer -->|Triggers| Script
    Script -->|1. Authenticate with Client ID/Secret| API
    API -->|2. Short-lived Access Token| Script
    Script -->|3. Generate new Reusable Auth Key| KeyGen
    KeyGen -->|4. Fresh tskey-auth-...| Script
    Script -->|5. Atomically update TS_AUTHKEY| SecretStore
    Script -->|6. Optional: Restart sidecars if needed| Containers
```

### Planned Implementation Phases:
1. **Tailscale Scoped OAuth Credentials**:
   * Create an OAuth Client in Tailscale Admin Settings restricted strictly to device key creation permissions (`keys:write`).
   * Store `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_CLIENT_SECRET` in `~/.bashrc.local` or SOPS age encrypted storage.
2. **Key Rotation Task Runner (`jl rotate-auth-key`)**:
   * Add a declarative task in `local-services/justfile` that queries the Tailscale API, retrieves a short-lived bearer token, generates a 90-day reusable auth key, and writes `TS_AUTHKEY=<new-key>` into `~/.local/share/local-services/.env`.
3. **Multi-Recipient SOPS Distribution (Zero-Key-Transfer Architecture)**:
   * **Host SSH Public Key Recipients**: In `.sops.yaml`, register the `ssh-ed25519` public keys of all authorized workstations (`asus`, `envy`, `arch`).
   * **No Private Key Distribution**: Private keys never leave their respective hosts; SOPS encrypts `secrets/tailscale.enc.yaml` such that any authorized device can decrypt with its existing local SSH key.
4. **Self-Healing Local Consumption (Lazy On-Demand Fallback)**:
   * **Zero Overhead**: Remote devices don't need continuous polling or background daemon timers.
   * **Lazy Fetch on Rejection**: If `jl up-remote` detects an expired auth token or `NeedsLogin` status, it triggers an automatic targeted `git pull` of `secrets/tailscale.enc.yaml`, decrypts the fresh key via local SSH key into `~/.local/share/local-services/.env`, and restarts the containers automatically.
   * **Periodic Fetch (Optional)**: Can optionally run as part of daily/weekly routines or during standard `./bootstrap.sh` self-tests.



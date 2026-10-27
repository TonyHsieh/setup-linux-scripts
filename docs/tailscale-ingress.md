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

## 🔮 Automated Auth Key Rotator (GitHub Actions + Multi-Recipient SOPS)

> [!NOTE]
> **Inspiration**: [How I Built a Tailscale Auth Key Rotator by Brent Gruber](https://medium.com/@brent.gruber77/how-i-built-a-tailscale-auth-key-rotator-814722b839e0)

### The Problem with Static Auth Keys
* Manual Tailscale auth keys have a strict **maximum lifespan of 90 days**.
* When an auth key expires, fresh machine bootstrapping or container recreation silently fails.
* Personal API access tokens are overly broad (granting full administrative control over the entire Tailnet).

### Architecture & Automated Workflow

```mermaid
flowchart TD
    subgraph GitHubCloud["☁️ GitHub Actions (Monthly Cron or Manual Trigger)"]
        GH_Secrets["GitHub Repo Secrets\n(TS_OAUTH_CLIENT_ID & SECRET)"]
        GH_Runner["Runner (.github/workflows/rotate-tailscale-key.yml)"]
        TS_API["Tailscale Token & Keys API\n(OAuth: keys:write)"]
        SOPS_Enc["SOPS Encryptor\n(Using .sops.yaml public keys)"]
        GitRepo["Git Commit & Push\n(secrets/tailscale.enc.yaml)"]
        
        GH_Secrets --> GH_Runner
        GH_Runner -->|1. Request Token & Mint 90d Key| TS_API
        TS_API -->|2. Fresh tskey-auth-...| GH_Runner
        GH_Runner -->|3. Re-encrypt with public keys| SOPS_Enc
        SOPS_Enc -->|4. Push to main| GitRepo
    end

    subgraph HostSystem["💻 Remote Workstation (Envy / Asus / Arch)"]
        JustUp["jl up-remote"]
        LazyPull["Lazy Fallback\n(Triggered if key expired)"]
        LocalSOPS["sops decrypt\n(Using local ~/.ssh/id_ed25519)"]
        LocalEnv["~/.local/share/local-services/.env\n(TS_AUTHKEY updated)"]
        Sidecars["Tailscale Sidecars\n(local-tailscale-*)"]

        GitRepo -.->|Lazy git pull| LazyPull
        JustUp -->|Status Check: NeedsLogin/Expired?| LazyPull
        LazyPull --> LocalSOPS
        LocalSOPS --> LocalEnv
        LocalEnv --> Sidecars
    end
```

### One-Time Setup Instructions:

#### Step 1: Create a Scoped OAuth Client in Tailscale
1. Open your [Tailscale OAuth Clients Settings](https://login.tailscale.com/admin/settings/oauth).
2. Click **Generate OAuth Client...**.
3. Under **Scopes**, select **`keys:write`** (Devices: Write Keys).
4. Copy the generated **Client ID** (`k...`) and **Client Secret** (`tskey-client-...`).

#### Step 2: Add Secrets to your GitHub Repository
1. In your GitHub repository, navigate to **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions**.
2. Click **New repository secret**:
   * Name: `TS_OAUTH_CLIENT_ID`, Secret: `<your-client-id>`
   * Name: `TS_OAUTH_CLIENT_SECRET`, Secret: `<your-client-secret>`

#### Step 3: Verify the Pipeline
1. Go to your repository's **Actions** tab on GitHub.
2. Select **Rotate Tailscale Auth Key** and click **Run workflow**.
3. The action runs in seconds, mints a fresh 90-day auth key, re-encrypts `secrets/tailscale.enc.yaml` with your devices' public keys, and commits it back to `main`.
4. On any laptop, simply run:
   ```bash
   jl sync-auth-key
   ```
   Or let `jl up-remote` lazily update it on-the-fly!




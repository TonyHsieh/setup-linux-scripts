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
| **Plex Media Server** | `https://plex-<machine>.komodo-sole.ts.net` | `https://plex.localhost` | Personal media streaming & transcoding server |
| **Remote Desktop (Web)** | `https://desktop-<machine>.komodo-sole.ts.net` | `localhost:3389 / krdp` | *(Planned)* Browser HTML5 remote desktop on Port 443 |
| **Remote SSH Terminal** | `ssh thsieh@<machine>` | `localhost:22` | *(Planned)* Zero-trust terminal shell via Tailscale SSH |

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

## 🔒 TLS Certificate Lifecycle & Automated Renewal

You do **not** need to manually renew certificates. Both local and remote layers feature automated lifecycle management:

| Certificate Domain | Authority | Validity | Renewal Mechanism | User Action Needed? |
| :--- | :--- | :--- | :--- | :--- |
| **`*.ts.net` (Remote Ingress)** | Let's Encrypt | 90 Days | Auto-renewed via ACME at **60 days** by the Tailscale sidecar | **No** (Fully hands-off) |
| **`*.localhost` (Local Mesh)** | `mkcert` Local CA | 825 Days (~2.3 yrs) | Auto-generated by `jl up` / `jl certs` | **No** (Auto-created if missing) |

### Key Details on Tailscale TLS Automation:
1. **ACME Background Renewal**: Each dedicated sidecar container runs the `tailscaled` daemon, which monitors the expiration date of its public Let's Encrypt certificate. Approximately 30 days before expiration, it contacts Let's Encrypt and renews the certificate with zero downtime.
2. **Persistence**: Certificates and machine cryptographic keys are saved inside persistent Podman volumes (`tailscale-<service>-state:/var/lib/tailscale`), ensuring renewed certificates survive laptop reboots and container upgrades.
3. **Automatic HTTP $\rightarrow$ HTTPS 301 Redirection**: Every sidecar binds Port 80 with `"HTTP": true` and issues an immediate HTTP `301 Moved Permanently` redirect to `https://${HOST}${REQUEST_URI}`. If a user enters `http://books-envy...` or omits `https://` on their mobile browser, the request is instantly upgraded to HTTPS.

---

## ❓ Frequently Asked Questions & Troubleshooting

### Q: What happens if I visit an endpoint over plain `http://` instead of `https://`?
All dedicated Tailscale ingress sidecars listen on Port 80 with an automated HTTP 301 Permanent Redirect. Visiting `http://pdf-envy.komodo-sole.ts.net` immediately bounces your browser to `https://pdf-envy.komodo-sole.ts.net`. Because it is a permanent 301 redirect, modern mobile and desktop browsers cache this rule and automatically request HTTPS on future visits.

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
> **Dedicated Guide**: See **[`docs/tailscale-auth-key-rotator.md`](tailscale-auth-key-rotator.md)** for complete operational instructions, security analysis, and troubleshooting.
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

---

## 🖥️ Remote Terminal Access via Tailscale SSH

Instead of configuring port forwarding, exposing port 22, or managing fragile public SSH keys across machines, **Tailscale SSH** provides zero-trust, identity-authenticated terminal access directly through the Tailnet WireGuard mesh.

### How It Works:
```mermaid
flowchart LR
    subgraph Client["📱 Remote Laptop / iPad / Phone"]
        SSHClient["SSH Client\n(ssh thsieh@envy)"]
    end

    subgraph TailscaleMesh["🔒 WireGuard Mesh (komodo-sole.ts.net)"]
        ControlPlane["Tailscale Control Plane\n(Identity & ACL Evaluation)"]
    end

    subgraph HostWorkstation["💻 Laptop Host (envy-cachyos-x8664)"]
        Tailscaled["tailscaled --ssh\n(Intercepts port 22 on tailscale0)"]
        LoginShell["Local User Shell\n(/bin/bash for thsieh)"]
    end

    SSHClient -->|Authenticated WireGuard| TailscaleMesh
    TailscaleMesh -->|Validated Identity| Tailscaled
    Tailscaled --> LoginShell
```

### Key Capabilities:
1. **Zero Key Management**: Tailscale proves your identity using your existing Tailscale account login. No passwords or `authorized_keys` files need to be copied.
2. **Encrypted Point-to-Point**: All traffic flows directly between devices over WireGuard.
3. **No Open Ports**: The host does not need port 22 open on local Wi-Fi or public routers.
4. **Usage**:
   ```bash
   ssh <username>@<machine-id>
   # Example:
   ssh thsieh@envy
   ```

---

## 🖥️ Dedicated Remote Desktop Entrypoint (`desktop-<machine>.komodo-sole.ts.net`)

To access laptop GUI desktops remotely without clumsy port numbers or third-party proprietary remote software, the system provides a dual-access architecture:

```mermaid
flowchart TD
    subgraph RemoteClients["📱 Remote Clients"]
        MobileBrowser["Mobile Safari / Chrome\n(iPhone / iPad / Laptop)"]
        NativeRDP["Microsoft Remote Desktop / Remmina\n(High-Performance Native Client)"]
    end

    subgraph TailnetMesh["🔒 Tailscale WireGuard Mesh"]
        TS_Desktop["local-tailscale-desktop\n(desktop-<machine>.komodo-sole.ts.net)"]
        HostTailscale["Host tailscaled\n(port 3389)"]
    end

    subgraph WorkstationHost["💻 Host Laptop (KDE Plasma 6 / Wayland)"]
        WebGateway["Web RDP HTML5 Client\n(docker-compose profile: desktop)"]
        KRDP["krdp Wayland Server\n(plasma-krdp.service on port 3389)"]
        PlasmaGUI["KDE Plasma 6 Session"]
    end

    MobileBrowser -->|Port 443 HTTPS (Auto TLS)| TS_Desktop
    TS_Desktop -->|Proxy :8080| WebGateway
    WebGateway -->|RDP :3389| KRDP

    NativeRDP -->|Direct RDP :3389 over Tailnet| HostTailscale
    HostTailscale --> KRDP
    KRDP --> PlasmaGUI
```

### Access Modalities:
1. **Clean Web Link (`https://desktop-<machine>.komodo-sole.ts.net`)**:
   - Standard **Port 443** with official Let's Encrypt TLS certificate.
   - Automatic **Port 80 HTTP $\rightarrow$ HTTPS 301 redirection**.
   - HTML5 in-browser canvas streaming: zero client software installation required on iOS or secondary laptops.
2. **Native Wayland RDP (`krdp`)**:
   - High-performance, low-latency display protocol directly integrated into KDE Plasma 6 Wayland on Arch/CachyOS.
   - Can be connected directly from Microsoft Remote Desktop on macOS/Windows or Remmina on Linux over the Tailscale mesh.

---

## 🧪 Automated Ingress & Security Regression Suite (`jl test-remote`)

To ensure that adding new services, rotating auth keys, or deploying across new machines never breaks existing security or networking invariants, an automated regression suite is maintained at `scripts/test-tailscale-ingress.sh`.

Run the test suite anytime:
```bash
jl test-remote
```

### What It Asserts (39+ Test Rules):
1. **Disk Secret Sanitization**: Asserts that `~/.local/share/local-services/.env` has zero plaintext `TS_AUTHKEY` entries and that `TS_MACHINE_ID` is set.
2. **In-Memory SOPS Decryption**: Asserts that `secrets/tailscale.enc.yaml` decrypts cleanly via the host SSH key (`~/.ssh/id_ed25519`).
3. **Rootless Podman DNS**: Validates upstream fallback DNS (`1.1.1.1`, `8.8.8.8`) in `containers.conf` to prevent ACME TLS certificate generation timeouts.
4. **Dedicated Ingress Sidecars Health**: Verifies all 6+ ingress containers are running in healthy status.
5. **Tailscale Serve Schema**: Asserts that Port 80 uses `"HTTP": true` (avoiding schema-drop bugs), Port 80 has an active 301 permanent redirect, Port 443 has `"HTTPS": true`, and Port 443 forwards to the correct internal proxy targets.
6. **Backend Services Health**: Verifies that `traefik-ingress`, `bentopdf`, `local-postgres`, `local-kavita`, and `local-plex` are running.





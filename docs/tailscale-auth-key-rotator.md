# 🔄 Tailscale Auth Key Rotator Guide (OAuth + Multi-Recipient SOPS)

This guide documents the automated, zero-touch **Tailscale Auth Key Rotator** architecture implemented in `setup-linux-scripts`. It keeps your containerized Tailscale ingress sidecars perpetually authenticated without manual intervention, eliminating the 90-day key expiration barrier.

> [!NOTE]
> **Architectural Reference**: Inspired by [How I Built a Tailscale Auth Key Rotator by Brent Gruber](https://medium.com/@brent.gruber77/how-i-built-a-tailscale-auth-key-rotator-814722b839e0).

---

## 🎯 1. The Problem with Static Tailscale Auth Keys

When deploying containerized or headless Tailscale nodes (such as our dedicated Port 443 ingress sidecars for BentoPDF, Open WebUI, Ollama, Kavita, and Traefik):

1. **Strict 90-Day Lifespan**: Tailscale reusable auth keys have a hard maximum expiration window of **90 days**. When an auth key expires, any container recreate or machine re-provisioning silently fails with authentication errors.
2. **Personal API Keys Are Over-Privileged**: Using personal API tokens carries excessive security risks because they grant full administrative access across your entire Tailnet.
3. **The "Secret Zero" Distribution Dilemma**: Distributing a shared secret across multiple laptops usually requires third-party SaaS platforms (Doppler, 1Password, Vault), creating external vendor dependencies and recurring fees.

---

## 🏛️ 2. Architectural Overview: GitOps + Multi-Recipient Encryption

Our solution combines **Tailscale Scoped OAuth**, **Serverless GitHub Actions**, and **Multi-Recipient SOPS with Host SSH Keys**:

```mermaid
flowchart TD
    subgraph TailscaleCloud["☁️ Tailscale Control Plane"]
        OAuth["Scoped OAuth Client\n(Scope: keys:write)"]
        TokenAPI["OAuth Token Endpoint\n(/api/v2/oauth/token)"]
        KeysAPI["Key Minting Endpoint\n(/api/v2/tailnet/{tailnet}/keys)"]
        
        OAuth --> TokenAPI --> KeysAPI
    end

    subgraph GitHubActions["⚙️ GitHub Actions (.github/workflows/rotate-tailscale-key.yml)"]
        CronTimer["Monthly Cron (1st of month)\nor Manual Trigger"]
        GH_Secrets["Repo Secrets:\nTS_OAUTH_CLIENT_ID\nTS_OAUTH_CLIENT_SECRET"]
        SOPS_Enc["SOPS Multi-Recipient Encryptor\n(Uses ONLY public keys in .sops.yaml)"]
        GitCommit["Atomic Git Commit & Push\n(secrets/tailscale.enc.yaml)"]

        CronTimer --> GH_Secrets --> SOPS_Enc --> GitCommit
    end

    subgraph LocalLaptops["💻 Authorized Laptops (Envy / Asus / Arch)"]
        RepoPull["Git Pull\n(Lazy on auth rejection or manual)"]
        LocalSSH["Local Host SSH Key\n(~/.ssh/id_ed25519 - NEVER leaves machine)"]
        SopsDec["sops --decrypt\n(scripts/sync-tailscale-key.sh)"]
        EnvFile["Local Services Environment\n(~/.local/share/local-services/.env)"]
        Containers["Podman Tailscale Sidecars\n(local-tailscale-*)"]

        GitCommit -.-> RepoPull
        RepoPull --> SopsDec
        LocalSSH --> SopsDec
        SopsDec --> EnvFile --> Containers
    end

    KeysAPI -->|Fresh 90d tskey-auth-...| GH_Secrets
```

### Key Security & Operational Highlights:

* **Zero Plaintext on Disk (In-Memory Decryption)**: Plaintext tokens are never stored on your laptop's filesystem. `jl up-remote` ephemerally decrypts `TS_AUTHKEY` into memory via SOPS for the few seconds needed to initialize container registration, and unsets it immediately after. `~/.local/share/local-services/.env` stores only non-sensitive configuration (`TS_MACHINE_ID`).
* **Zero Private Keys in Transit**: SOPS encrypts using only **public keys** (`ssh-ed25519` and `age`). No private keys ever leave your workstations or touch GitHub.
* **Serverless Rotation**: A GitHub Actions workflow runs once a month on a schedule, mints a fresh 90-day reusable key via scoped OAuth, re-encrypts `secrets/tailscale.enc.yaml`, and pushes to `main`.
* **Lazy On-Demand Fallback**: Remote laptops don't need continuous background daemons. Once registered, Tailscale caches its node identity in the persistent container volume (`/var/lib/tailscale`) and rarely needs the token again. If bringing up fresh or wiped nodes, `jl up-remote` fetches the latest encrypted key on the fly.

---

## 🚀 3. One-Time Setup Instructions

### Step 1: Create a Scoped OAuth Client in Tailscale

1. Open the [Tailscale OAuth Clients Console](https://login.tailscale.com/admin/settings/oauth).
2. Click **Generate OAuth Client...**.
3. Under **Scopes**, select only **`keys:write`** (Devices: Write Keys).
4. Copy the generated credentials:
   * **Client ID**: starts with `k...`
   * **Client Secret**: starts with `tskey-client-...`

### Step 2: Add Secrets to your GitHub Repository

1. Open your private repository on GitHub.
2. Go to **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions**.
3. Click **New repository secret** and add:
   * `TS_OAUTH_CLIENT_ID`: `<your-tailscale-client-id>`
   * `TS_OAUTH_CLIENT_SECRET`: `<your-tailscale-client-secret>`

### Step 3: Trigger the First Automated Key Rotation

1. In GitHub, navigate to the **Actions** tab.
2. Select the workflow **Rotate Tailscale Auth Key** in the left sidebar.
3. Click **Run workflow** $\rightarrow$ **Run workflow**.
4. The workflow will run in ~10 seconds:
   * It exchanges the credentials for an ephemeral bearer token.
   * Mints a fresh 90-day reusable Tailscale auth key.
   * Encrypts the payload with SOPS for all authorized devices in [`.sops.yaml`](../.sops.yaml).
   * Commits `secrets/tailscale.enc.yaml` to `main`.

---

## 🛠️ 4. Day-to-Day Operations & Tasks

All operations are automated through the `jl` task runner:

### 1. Start Services with In-Memory Secret Injection (`jl up-remote`)
When you run `jl up-remote`, it ephemerally decrypts `TS_AUTHKEY` from `secrets/tailscale.enc.yaml` into RAM, passes it to the container mesh, and unsets it immediately:
```bash
jl up-remote
```
Zero plaintext tokens are written to disk. Once registered, the nodes persist their machine identity in `/var/lib/tailscale`.

### 2. Verify Decryption & Sanitize Local Disk (`jl sync-auth-key`)
To verify that your host SSH key can decrypt secrets and ensure no stale tokens are sitting in your local `.env`:
```bash
jl sync-auth-key
```

### 3. Manual On-Demand Key Rotation (`jl rotate-auth-key`)
If you have `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_CLIENT_SECRET` exported in your local `~/.bashrc.local`, you can rotate keys directly from your terminal:
```bash
jl rotate-auth-key --commit
git push origin main
```

---

## ➕ 5. Adding a New Machine & The Cryptographic "Vault" Rule

When onboarding a new laptop (e.g., `asus`), you might wonder:  
> **"Why can't the new laptop authorize itself directly? Why does authorization require running `sops updatekeys` on an already-authorized laptop (like `envy`) or triggering the GitHub Actions workflow?"**

### 🔐 The Cryptographic Reason: Envelope Encryption (DEK vs. KEK)

SOPS uses **Envelope Encryption**:

```mermaid
flowchart TD
    subgraph SecretVault["🔒 secrets/tailscale.enc.yaml (Encrypted Vault)"]
        Payload["Plaintext Tailscale Auth Key\n(tskey-auth-...)"]
        DEK["Internal Data Encryption Key (DEK)\n(Random 256-bit AES Key)"]
        Payload <-->|Encrypted by| DEK
    end

    subgraph AuthorizedKeys["🔑 Key Encryption Keys (KEK - Listed in .sops.yaml)"]
        EnvyKey["Envy SSH Public Key\n(AAAAC3Nza...envy)"]
        AsusKey["Asus SSH Public Key\n(AAAAC3Nza...asus)"]
        AgeKey["GitHub Actions Master Age Key\n(age1k5z7...)"]

        DEK -->|Encrypted Copy 1| EnvyKey
        DEK -.->|Needs Authorization| AsusKey
        DEK -->|Encrypted Copy 3| AgeKey
    end

    subgraph Hosts["💻 Workstations"]
        EnvyHost["envy laptop\n(Holds Envy Private Key ✅)"]
        AsusHost["asus laptop\n(Holds Asus Private Key ❌ Not in vault yet)"]
        GHActions["GitHub Actions Runner\n(Holds Tailscale OAuth Credentials ☁️)"]
    end

    EnvyHost -->|Can decrypt DEK & add Asus| SecretVault
    AsusHost -.->|CANNOT open vault yet!| SecretVault
    GHActions -->|Can mint fresh key & re-encrypt for ALL| SecretVault
```

1. **The Secret is Locked by an Internal Key (DEK)**:
   The sensitive token is encrypted with a random 256-bit AES Data Encryption Key.
2. **The Internal Key is Locked by Recipient Public Keys (KEKs)**:
   SOPS stores an encrypted copy of this AES key for every authorized recipient listed in `.sops.yaml`.
3. **The Chicken-and-Egg Paradox on a New Laptop**:
   - Adding Asus's public key to `.sops.yaml` is simply adding a new name to the "Allowed Visitors" list outside the vault door.
   - To actually encrypt the AES data key for Asus (`sops updatekeys`), SOPS must **first decrypt** the existing AES data key using an authorized **private key**.
   - Asus **does not have Envy's private key** (private keys never leave their host machine). Nor does Asus have the master Age private key.
   - If *any* newly cloned machine could run `sops updatekeys` and add its own key without possessing an existing authorized private key, **the entire security model would be destroyed**—anyone could clone your repo and decrypt all your private secrets!

---

### 🚀 Two Ways to Authorize a New Laptop

#### Method A: Fully Automated via GitHub Actions (Zero Cross-Laptop Typing)
Because `.github/workflows/rotate-tailscale-key.yml` triggers on any push to `.sops.yaml`:
1. On the new laptop (`asus`), run:
   ```bash
   jl register-key --commit
   git push origin main
   ```
2. GitHub Actions detects the `.sops.yaml` commit, runs the rotation workflow, mints/re-encrypts the secret using **all** public keys in `.sops.yaml` (including Asus), and commits the result back to `main`.
3. On the new laptop, simply run:
   ```bash
   git pull origin main
   ```
   *Asus can now immediately decrypt `secrets/tailscale.enc.yaml` locally in memory!*

#### Method B: Peer Authorization from an Existing Laptop (`envy`)
If you are already sitting at your authorized laptop (`envy`):
1. On `envy`:
   ```bash
   git pull origin main
   sops updatekeys -y secrets/tailscale.enc.yaml
   git commit -am "chore(sops): re-encrypt for asus"
   git push origin main
   ```
2. On `asus`:
   ```bash
   git pull origin main
   ```

Now the new laptop can immediately decrypt `secrets/tailscale.enc.yaml` during `./bootstrap.sh` using its own local private SSH key!

---

## ❓ Frequently Asked Questions

### Q: What if a laptop has been offline or turned off for more than 90 days?
Since GitHub Actions rotates the key on the 1st of every month in the repository, whenever the laptop is turned back on:
1. Run `git pull`.
2. Run `jl sync-auth-key` (or simply `jl up-remote`).
Your machine immediately decrypts the latest valid key and connects.

### Q: Why not use Doppler, HashiCorp Vault, or 1Password Connect?
SaaS secret managers introduce monthly costs, closed-source dependencies, and external network failure points. Storing SOPS-encrypted secrets directly in your private Git repository guarantees 100% data ownership, cryptographic privacy, offline resilience, and zero vendor lock-in.

### Q: Can GitHub Actions see my decrypted secrets?
No. GitHub Actions only holds the scoped OAuth Client credentials (`keys:write`). It mints a *new* auth key via API and uses your *public* keys in `.sops.yaml` to encrypt it into ciphertext before committing. GitHub never has access to the private SSH keys required to decrypt the payload.

### Q: Does this workflow also renew my TLS/HTTPS certificates?
No, because Tailscale handles TLS certificates automatically!
- **Auth Key (`tskey-auth-...`)**: Rotated monthly by GitHub Actions to grant containers permission to register on your Tailnet.
- **TLS Certificates (`*.ts.net`)**: Once registered, each sidecar container's `tailscaled` daemon automatically requests and renews its public Let's Encrypt certificate via ACME every 60 days in the background. All endpoints also bind Port 80 with an automatic HTTP 301 redirect to HTTPS. Zero manual maintenance is required for either layer!

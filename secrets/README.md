# 🔐 Multi-Recipient Encrypted Secrets (SOPS + age/SSH)

This directory contains version-controlled, encrypted secrets managed by **SOPS** and decrypted locally using **age** or native **SSH keys (`ssh-ed25519`)**.

---

## 🏗️ How Multi-Recipient Encryption Works

Secrets in this directory are encrypted using the public keys listed in [`.sops.yaml`](../.sops.yaml):
* **No Private Keys in Git**: Only public keys are stored in configuration; private keys (`~/.ssh/id_ed25519` or `~/.config/sops/age/keys.txt`) never leave their respective hosts.
* **Multi-Device Decryption**: Any authorized machine whose SSH public key is registered in `.sops.yaml` can independently decrypt these files.

---

## 🔑 Available Encrypted Secrets

### `secrets/tailscale.enc.yaml`
Contains the automated Tailscale authentication key and optional OAuth client credentials:
```yaml
tailscale:
  auth_key: "tskey-auth-..."
  oauth_client_id: ""
  oauth_client_secret: ""
```

---

## 🛠️ Management Commands

Using the `jl` task runner from anywhere in the repository:

```bash
# Decrypt the latest auth key from Git and apply it to ~/.local/share/local-services/.env:
jl sync-auth-key

# Rotate the Tailscale auth key via OAuth API and update the encrypted secret:
jl rotate-auth-key
```

---

## ➕ Adding a New Laptop to `.sops.yaml`

When onboarding a new machine (e.g. `AsusGA403u` or a new work laptop):
1. Obtain the machine's public SSH key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
2. Append the public key to [`.sops.yaml`](../.sops.yaml) under the `age:` recipient list:
   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.enc\.ya?ml$
       age: >-
         age1...,
         ssh-ed25519 AAAAC3NzaC1l... user@envy,
         ssh-ed25519 AAAAC3NzaC1l... user@new-laptop
   ```
3. Re-encrypt all existing secret files so the new machine can decrypt them:
   ```bash
   sops updatekeys secrets/tailscale.enc.yaml
   git commit -am "chore(secrets): add new-laptop SSH public key to SOPS recipients"
   ```

# 🏛️ Legacy v1.x Scripts Archive

> [!CAUTION]
> **DO NOT run `uninstall-dev-env.sh` or `install-dev-env.sh` on an active Nix v2.0 installation!**  
> These imperative scripts mutate global system directories (`/usr/local/bin`, `/etc/apt/keyrings`) and will remove or corrupt active Home Manager symlinks (such as `~/.bashrc`, `~/.config/nvim`, or `~/.nix-profile`).

---

## 📌 About This Directory

This directory preserves the original imperative bash scripts and static dotfiles from **v1.x** of `setup-linux-scripts`:

| File | Purpose in v1.x | v2.0 Declarative Replacement |
| :--- | :--- | :--- |
| `install-dev-env.sh` | Monolithic package and tool installer (`apt`, `brew`, `pacman`) | [`bootstrap.sh`](../bootstrap.sh) + [`home/`](../home/) (Home Manager) |
| `install-local-services.sh` | Podman local service deployment script | [`local-services/justfile`](../local-services/justfile) (`jl up`) |
| `setup-starship.sh` | Manual Starship installer and config deployment | [`home/starship.nix`](../home/starship.nix) + [`dotfiles/starship.toml`](../dotfiles/starship.toml) |
| `remove-lunarvim.sh` | LunarVim cleanup helper | Not needed; Neovim managed via Nix Flake |
| `uninstall-dev-env.sh` | Imperative uninstaller for v1.x packages | [`./bootstrap.sh --cleanup`](../bootstrap.sh) / `home-manager generations` |
| `uninstall-local-services.sh` | Imperative local services teardown | `jl down` in [`local-services/`](../local-services/) |
| `.bashrc` | Imperative bash template copied to `~/.bashrc` | [`home/shell.nix`](../home/shell.nix) |
| `.tmux.conf` | Imperative tmux template copied to `~/.tmux.conf` | [`home/tmux.nix`](../home/tmux.nix) |

---

## 🚀 Active v2.0 Documentation

Please refer to the main repository documentation for all current workflows:
* [Main README](../README.md)
* [Local Services Mesh Guide](../docs/local-services.md)
* [Conversion Plan & Architecture](../convert-to-dev-env-nix-plan.md)

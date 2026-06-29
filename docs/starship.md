# 🚀 Starship Prompt Features

[Starship](https://starship.rs/) is a minimal, blazing-fast, and infinitely customizable prompt for any shell. It is written in Rust and designed to make your terminal prompt intelligent, fast, and visually clean.

---

## 🌟 Core Features of Starship

- **Blazing Fast**: Written in Rust, it renders virtually instantly, preventing the cursor lag often associated with heavy shell themes.
- **Cross-Shell Compatibility**: Works out of the box on `bash`, `zsh`, `fish`, `powershell`, `elvish`, `nushell`, and more.
- **Out-of-the-Box Integrations**: Built-in modules automatically detect if you are in a Git repository, inside a Docker container, logged into AWS/GCP/Azure, or editing code for a specific programming language.
- **Nerd Font Support**: Leverages standard Nerd Font glyphs to show clear icons for different tools, languages, and environments.
- **Intelligent Visibility**: Modules only display when relevant. For example, the Rust logo and version only show if you are inside a project with Rust files.

---

## ⚙️ Installation & Setup in this Repository

Our installation script ([`install-dev-env.sh`](file:///home/tonyh/_Projects/setup-linux-scripts/install-dev-env.sh)) automates the setup of Starship:

1. **Installation**:
   - **macOS**: Installed via Homebrew (`brew install starship`).
   - **Arch Linux**: Installed via pacman (`sudo pacman -S starship`).
   - **Debian / Ubuntu**: Installed via the official installation script (`curl -sS https://starship.rs/install.sh | sh`).
2. **Configuration**:
   - The [`setup-starship.sh`](file:///home/tonyh/_Projects/setup-linux-scripts/setup-starship.sh) script copies our customized [`starship.toml`](file:///home/tonyh/_Projects/setup-linux-scripts/starship.toml) to `~/.config/starship.toml`.
3. **Activation**:
   - Added to the system [`~/.bashrc`](file:///home/tonyh/_Projects/setup-linux-scripts/.bashrc) using the following hook:
     ```bash
     if command -v starship >/dev/null 2>&1; then
       eval "$(starship init bash)"
     fi
     ```

---

## 📖 Custom Configurations

To see the exact details of the prompt styling, backgrounds, custom commands, and symbols defined for this environment, refer to the [Starship TOML Features Guide](file:///home/tonyh/_Projects/setup-linux-scripts/docs/starship-toml.md).

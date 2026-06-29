# 🪟 TMUX Configuration (`.tmux.conf`) Features

This document provides a detailed breakdown of the custom TMUX configuration defined in [`.tmux.conf`](file:///home/tonyh/_Projects/setup-linux-scripts/.tmux.conf), which is deployed to `~/.tmux.conf`.

---

## 🌟 Core Features & Enhancements

### 1. Shell & Environment Basics
- **Shell**: Automatically defaults to `/bin/bash`. On macOS, it dynamically overrides this to use Homebrew-installed Bash if available.
- **Color Support**: Configured to support 256 colors (`screen-256color`).
- **Low Latency**: `escape-time` is set to `0` to prevent delayed command inputs (especially useful for Vim users).
- **Mouse Support**: Enabled (`mouse on`), allowing you to click to select panes, drag pane borders to resize them, and scroll through the output history.
- **Scrollback History**: Buffer limit increased to `100,000` lines (default is 2,000).

### 2. Vi-Style Copy & Paste Mode
- **Vi Bindings**: Enables Vi-like movement and search keys in copy mode (`set -g mode-keys vi`).
- **Enhanced Entry**: Pressing `Ctrl+b [` enters copy mode and immediately scrolls up.
- **Visual Selection**:
  - `v` begins visual selection (behaves like Vim's visual mode).
  - `V` selects the current line.

### 3. Intelligent Clipboard Integration
The configuration automatically detects your operating system and display server environment to pipe copied text directly to the system clipboard:

| Environment | Clipboard Tool | Detection Method |
| :--- | :--- | :--- |
| **WSL (Windows)** | `clip.exe` | Checks if `Microsoft` is in `/proc/version` |
| **macOS** | `pbcopy` | Checks if `/usr/bin/pbcopy` exists |
| **Wayland Linux** | `wl-copy` | Checks if `$WAYLAND_DISPLAY` is set |
| **X11 Linux (Fallback)** | `xclip` | Standard fallback |

### 4. Vim-Like Pane Navigation & Resizing
No need to use arrow keys. You can navigate and resize panes using familiar Vim keys:
- **Navigation**:
  - `Ctrl+b h` -> Move cursor left
  - `Ctrl+b j` -> Move cursor down
  - `Ctrl+b k` -> Move cursor up
  - `Ctrl+b l` -> Move cursor right
- **Resizing**:
  - `Ctrl+b H` -> Resize pane left by 5 columns (repeatable)
  - `Ctrl+b J` -> Resize pane down by 5 rows (repeatable)
  - `Ctrl+b K` -> Resize pane up by 5 rows (repeatable)
  - `Ctrl+b L` -> Resize pane right by 5 columns (repeatable)

### 5. Layout & Window Management
- **1-Based Indexing**: Windows and panes start indexing at `1` (instead of `0`) so they align with the physical keyboard number row layout.
- **Auto-Rename**: Automatically renames windows dynamically based on the command executing in the active shell.
- **Config Reloading**: Reload your TMUX configuration instantly without closing your session by pressing `Ctrl+b r`. It displays a confirmation notification when done.

### 6. TPM Plugins & Session Persistence
The configuration integrates [Tmux Plugin Manager (TPM)](https://github.com/tmux-plugins/tpm) to load and manage the following plugins:
- **`tmux-plugins/tmux-sensible`**: Applies common, community-accepted default settings.
- **`tmux-plugins/tmux-resurrect`**: Saves and restores your TMUX environment (windows, panes, layouts, and programs) manually (`Ctrl+b Ctrl+s` to save, `Ctrl+b Ctrl+r` to restore).
- **`tmux-plugins/tmux-continuum`**: Automates environment saving every 15 minutes. Automatically restores your last saved session upon starting TMUX (`set -g @continuum-restore 'on'`).

### 7. Cursor Styling
- Integrates with modern line editors (such as `ble.sh`) to force an underline cursor shape within the active terminal pane.

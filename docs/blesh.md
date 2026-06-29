# ⌨️ ble.sh (Bash Line Editor) Features

[ble.sh](https://github.com/akinomyoga/ble.sh) is a full-featured line editor written in pure Bash that replaces the default GNU Readline library for command-line editing in interactive shells.

---

## 🌟 Core Features of ble.sh

- **Real-Time Syntax Highlighting**: Colorizes commands, arguments, option flags, strings, quotes, variables, redirections, and comments as you type. Typos/invalid command names are automatically highlighted in red.
- **Fish-Like Auto-Suggestions**: Offers history-based command autocomplete recommendations inline in a dimmed font. Pressing the right arrow key or `Ctrl+f` completes the suggested text.
- **Enhanced Auto-Completion Menu**: Provides an interactive, scrollable selection menu for completions (such as files, directories, git branches, or flags) with mouse support and tooltips.
- **Vim Modal Editing**: Supports full Vim mode for command-line editing (Normal, Insert, and Visual modes) directly in your terminal.
- **Subshell & Pipeline Support**: Maintains full capability inside pipelines and subshell execution blocks.
- **Pure Bash Implementation**: Written entirely in Bash scripts, making it highly portable across systems with a modern bash shell.

---

## ⚙️ Installation & Setup in this Repository

Our installation script ([`install-dev-env.sh`](file:///home/tonyh/_Projects/setup-linux-scripts/install-dev-env.sh)) automates the setup of ble.sh:

1. **Installation**:
   - **macOS**: Cloned from GitHub and compiled/installed locally via `make install PREFIX="$HOME/.local"`.
   - **Arch Linux**: Installed via the AUR package `blesh-git`.
   - **Debian / Ubuntu**: Cloned from GitHub and compiled/installed locally to `~/.local/share/blesh`.
2. **Integration Flow in [`~/.bashrc`](file:///home/tonyh/_Projects/setup-linux-scripts/.bashrc)**:
   - **Early Initialization**: Initialized with `--noattach` at the top of the file to prepare the environment:
     ```bash
     if [[ $- == *i* ]]; then
       if [[ -r /usr/share/blesh/ble.sh ]]; then
         source /usr/share/blesh/ble.sh --noattach
       elif [[ -r "$HOME/.local/share/blesh/ble.sh" ]]; then
         source "$HOME/.local/share/blesh/ble.sh" --noattach
       fi
       ...
     fi
     ```
   - **Custom Auto-Complete Styling**: Configures the autocomplete prediction to use a subtle gray color and underline rather than a solid background block:
     ```bash
     if type ble-face >/dev/null 2>&1; then
       ble-face auto_complete='fg=242,bg=,underline'
     fi
     ```
   - **Cursor Style**: Forces a flatline (underline) cursor in the editor:
     ```bash
     printf '\e[4 q'
     ```
   - **Late Attachment**: Attached at the very bottom of the `.bashrc` file to ensure it captures all alias definitions and shell functions correctly:
     ```bash
     if [[ $- == *i* ]] && type ble-attach >/dev/null 2>&1; then
       ble-attach
     fi
     ```

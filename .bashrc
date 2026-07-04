############################################################
# ~/.bashrc
# Purpose: Clean, predictable bash setup for infra/dev work
# Includes: starship (powerline-style), rust, vim, zed
############################################################
##### 1. Shell behavior & safety #####

# Initialize ble.sh (Bash Line Editor) early if present in an interactive shell
if [[ $- == *i* ]]; then
  if [[ -r /usr/share/blesh/ble.sh ]]; then
    source /usr/share/blesh/ble.sh --noattach
  elif [[ -r "$HOME/.local/share/blesh/ble.sh" ]]; then
    source "$HOME/.local/share/blesh/ble.sh" --noattach
  fi

  # Underline the auto-complete predictions and clear the background highlight
  if type ble-face >/dev/null 2>&1; then
    ble-face auto_complete='fg=242,bg=,underline'
  fi
fi

# In ble.sh - Always use flatline (underline) cursor
printf '\e[4 q'


# Enable extended globbing equivalents
shopt -s extglob
shopt -s nocaseglob
shopt -s autocd

# Enable ** globbing (bash equivalent of zsh extendedglob/globstar)
shopt -s globstar

# Disable terminal bell
set +o notify
[[ $- == *i* ]] && bind 'set bell-style none'


##### 2. History #####
HISTFILE="$HOME/.bash_history"
HISTSIZE=10000
HISTFILESIZE=10000

# Append history, avoid duplicates, trim blanks
shopt -s histappend
export HISTCONTROL=ignoredups:erasedups
export HISTIGNORE="ls:ll:la:pwd:exit:clear"

# Sync history between sessions
PROMPT_COMMAND='history -a; history -n'


##### 3. PATH & core environment #####

# Homebrew (Apple Silicon)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# SSH agent (bash-safe, avoids spawning multiples)
if [[ -z "$SSH_AUTH_SOCK" ]]; then
  eval "$(ssh-agent -s)" >/dev/null
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519_bitbucket >/dev/null 2>&1
  else
    ssh-add ~/.ssh/id_ed25519_bitbucket >/dev/null 2>&1
  fi
fi

# User paths
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"


# Rust (installed via rustup)
if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

# Editors
export EDITOR=vim
export VISUAL=vim


##### 4. Completion system #####

# Load bash completion via Homebrew if present, fallback to standard Linux paths
if command -v brew >/dev/null 2>&1 && [[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]]; then
  source "$(brew --prefix)/etc/profile.d/bash_completion.sh"
elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
elif [[ -r /usr/local/etc/profile.d/bash_completion.sh ]]; then
  source /usr/local/etc/profile.d/bash_completion.sh
fi


##### 5. Prompt (Powerline-style via Starship) #####
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
  alias nix-shell='nix-shell --command "exec bash"'
fi

##### 6. Aliases #####
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

alias gs='git status'
alias gl='git log --oneline --decorate --graph'
alias gd='git diff'
alias gc='git commit'
alias gp='git push'

alias k='kubectl'
alias vi='vim'

alias up='cd ..'


# WSL clipboard helper aliases (mimic macOS pbcopy/pbpaste)
if grep -qsi Microsoft /proc/version; then
  if ! command -v pbcopy >/dev/null 2>&1; then
    alias pbcopy='clip.exe'
  fi
  if ! command -v pbpaste >/dev/null 2>&1; then
    alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard | tr -d "\r"'
  fi
fi

### 7. Artifactory Info ###
export ARTIFACTORY_REGISTRY="xx"
export ARTIFACTORY_USER="xxx"


#### #7. Directory setup (idempotent symlinks) #####
DEV_SOURCES=(
  "/Users/thsieh01/Library/CloudStorage/OneDrive-BlueShieldofCalifornia/_dev"
  "$HOME/OneDrive-BlueShieldofCalifornia/_dev"
  "$HOME/OneDrive/_dev"
  "$HOME/onedrive/_dev"
)
PROD_SOURCES=(
  "/Users/thsieh01/Library/CloudStorage/OneDrive-BlueShieldofCalifornia/_prod"
  "$HOME/OneDrive-BlueShieldofCalifornia/_prod"
  "$HOME/OneDrive/_prod"
  "$HOME/onedrive/_prod"
)

# Under WSL, dynamically append Windows OneDrive path candidates
if grep -qsi Microsoft /proc/version; then
  for d in /mnt/c/Users/*/OneDrive-BlueShieldofCalifornia/_dev; do
    [[ -d "$d" ]] && DEV_SOURCES+=("$d")
  done
  for d in /mnt/c/Users/*/OneDrive/_dev; do
    [[ -d "$d" ]] && DEV_SOURCES+=("$d")
  done
  for d in /mnt/c/Users/*/onedrive/_dev; do
    [[ -d "$d" ]] && DEV_SOURCES+=("$d")
  done

  for d in /mnt/c/Users/*/OneDrive-BlueShieldofCalifornia/_prod; do
    [[ -d "$d" ]] && PROD_SOURCES+=("$d")
  done
  for d in /mnt/c/Users/*/OneDrive/_prod; do
    [[ -d "$d" ]] && PROD_SOURCES+=("$d")
  done
  for d in /mnt/c/Users/*/onedrive/_prod; do
    [[ -d "$d" ]] && PROD_SOURCES+=("$d")
  done
fi

DEV_TARGET="$HOME/_dev"
PROD_TARGET="$HOME/_prod"

if [[ ! -e "$DEV_TARGET" ]]; then
  for src in "${DEV_SOURCES[@]}"; do
    if [[ -d "$src" ]]; then
      ln -s "$src" "$DEV_TARGET"
      break
    fi
  done
fi

if [[ ! -e "$PROD_TARGET" ]]; then
  for src in "${PROD_SOURCES[@]}"; do
    if [[ -d "$src" ]]; then
      ln -s "$src" "$PROD_TARGET"
      break
    fi
  done
fi


##### 8. Functions #####
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}


##### 9. AZ CLI requirements #####
if python3 -c "import certifi" >/dev/null 2>&1; then
  CERT_PATH=$(python3 -m certifi)
  export SSL_CERT_FILE=${CERT_PATH}
  export REQUESTS_CA_BUNDLE=${CERT_PATH}
fi


##### XX. Optional local overrides #####
# Keeps this file clean and portable
[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local

############################################################
# End of ~/.bashrc
############################################################
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

# Remove duplicate entries
export PATH=$(printf "%s" "$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++')


# Attach ble.sh at the very end of bashrc if present in an interactive shell
if [[ $- == *i* ]] && type ble-attach >/dev/null 2>&1; then
  ble-attach
fi

{ pkgs, lib, ... }:

{
  programs.bash.initExtra = ''
    # Homebrew shell environment (Apple Silicon & Intel)
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    # SSH agent Keychain integration
    if [[ -z "$SSH_AUTH_SOCK" ]]; then
      eval "$(ssh-agent -s)" >/dev/null
      ssh-add --apple-use-keychain ~/.ssh/id_ed25519_bitbucket >/dev/null 2>&1 || true
    fi

    # Generic OneDrive directory discovery for macOS (personal or any employer)
    DEV_TARGET="$HOME/_dev"
    PROD_TARGET="$HOME/_prod"

    if [[ ! -e "$DEV_TARGET" ]]; then
      for candidate in "$HOME/Library/CloudStorage"/[Oo]ne[Dd]rive*/_dev "$HOME"/[Oo]ne[Dd]rive*/_dev; do
        if [[ -d "$candidate" ]]; then
          ln -s "$candidate" "$DEV_TARGET"
          break
        fi
      done
    fi

    if [[ ! -e "$PROD_TARGET" ]]; then
      for candidate in "$HOME/Library/CloudStorage"/[Oo]ne[Dd]rive*/_prod "$HOME"/[Oo]ne[Dd]rive*/_prod; do
        if [[ -d "$candidate" ]]; then
          ln -s "$candidate" "$PROD_TARGET"
          break
        fi
      done
    fi
  '';
}

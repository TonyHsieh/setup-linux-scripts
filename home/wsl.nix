{ pkgs, lib, ... }:

{
  # WSL-specific aliases
  programs.bash.shellAliases = {
    pbcopy = "clip.exe";
    pbpaste = "powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\\r'";
  };

  # WSL-specific shell integration hooks
  programs.bash.initExtra = ''
    # WSL2 Wayland socket symlink for systemd
    if [[ -d "/mnt/wslg/runtime-dir" && -n "$XDG_RUNTIME_DIR" && -d "$XDG_RUNTIME_DIR" ]]; then
      w_disp="''${WAYLAND_DISPLAY:-wayland-0}"
      if [[ ! -S "$XDG_RUNTIME_DIR/$w_disp" && -S "/mnt/wslg/runtime-dir/$w_disp" ]]; then
        ln -sf "/mnt/wslg/runtime-dir/$w_disp" "$XDG_RUNTIME_DIR/$w_disp"
        if [[ -f "/mnt/wslg/runtime-dir/$w_disp.lock" ]]; then
          ln -sf "/mnt/wslg/runtime-dir/$w_disp.lock" "$XDG_RUNTIME_DIR/$w_disp.lock"
        fi
      fi
    fi

    # Generic OneDrive directory discovery (works for personal or any employer OneDrive)
    DEV_TARGET="$HOME/_dev"
    PROD_TARGET="$HOME/_prod"

    if [[ ! -e "$DEV_TARGET" ]]; then
      for candidate in "$HOME"/[Oo]ne[Dd]rive*/_dev /mnt/c/Users/*/[Oo]ne[Dd]rive*/_dev; do
        if [[ -d "$candidate" ]]; then
          ln -s "$candidate" "$DEV_TARGET"
          break
        fi
      done
    fi

    if [[ ! -e "$PROD_TARGET" ]]; then
      for candidate in "$HOME"/[Oo]ne[Dd]rive*/_prod /mnt/c/Users/*/[Oo]ne[Dd]rive*/_prod; do
        if [[ -d "$candidate" ]]; then
          ln -s "$candidate" "$PROD_TARGET"
          break
        fi
      done
    fi
  '';
}

{ pkgs, lib, ... }:

{
  # WSL-specific aliases
  programs.bash.shellAliases = {
    pbcopy = "clip.exe";
    pbpaste = "powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\\r'";
    nvidia-smi = "/usr/lib/wsl/lib/nvidia-smi";
  };

  # WSL-specific shell integration hooks
  programs.bash.initExtra = ''
    # Ensure WSL2 driver shim directory is in PATH for nvidia-smi
    if [ -d "/usr/lib/wsl/lib" ] && [[ ":$PATH:" != *":/usr/lib/wsl/lib:"* ]]; then
      export PATH="/usr/lib/wsl/lib:$PATH"
    fi

    # WSL2 CUDA acceleration helper for interactive / ad-hoc shell sessions
    wsl-cuda() {
      if [ -d "/usr/lib/wsl/lib" ]; then
        export LD_LIBRARY_PATH="/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        echo "🚀 WSL2 NVIDIA/CUDA drivers enabled (LD_LIBRARY_PATH += /usr/lib/wsl/lib)"
      else
        echo "⚠️  /usr/lib/wsl/lib not found. Ensure NVIDIA Windows drivers are installed on the host." >&2
      fi
    }

    # Patch any Python virtualenv to automatically include WSL2 CUDA libraries on activation
    patch-venv-cuda() {
      local venv_path="''${1:-.venv}"
      local activate_script="$venv_path/bin/activate"
      if [ -f "$activate_script" ]; then
        if grep -q "/usr/lib/wsl/lib" "$activate_script"; then
          echo "ℹ️  WSL2 CUDA already configured in $activate_script"
        else
          echo "" >> "$activate_script"
          echo "# WSL2 GPU Acceleration: expose Windows NVIDIA CUDA driver shims" >> "$activate_script"
          echo 'if [ -d "/usr/lib/wsl/lib" ]; then' >> "$activate_script"
          echo '    export LD_LIBRARY_PATH="/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"' >> "$activate_script"
          echo 'fi' >> "$activate_script"
          echo "✅ Patched $activate_script with WSL2 CUDA LD_LIBRARY_PATH"
        fi
      else
        echo "⚠️  Activation script not found at: $activate_script" >&2
        return 1
      fi
    }
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

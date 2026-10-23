{ pkgs, ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;

    historySize = 10000;
    historyFileSize = 10000;
    historyControl = [ "ignoredups" "erasedups" ];
    historyIgnore = [ "ls" "ll" "la" "pwd" "exit" "clear" ];
    shellOptions = [ "extglob" "nocaseglob" "autocd" "globstar" "histappend" ];

    # Global, permanent aliases tracked in Git across all machines.
    # Applied via: ./bootstrap.sh
    # NOTE: For machine-specific, temporary, or private aliases (not in Git),
    # add them to ~/.bashrc.local instead (sourced in Section 6 below).
    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
      l = "ls -CF";

      gs = "git status";
      gl = "git log --oneline --decorate --graph";
      gd = "git diff";
      gc = "git commit";
      gp = "git push";

      k = "kubectl";
      vi = "nvim";
      vim = "nvim";
      up = "cd ..";

      # AI Agent Shorthands
      oc = "opencode";
      ha = "hermes";

      # Local Services Mesh Task Runner (just)
      jl = "just -f ~/.local/share/local-services/justfile";

      # Quick Tmux launcher
      t = "tmux";
    };

    initExtra = ''
      ##### 1. ble.sh (Bash Line Editor) Integration #####
      # Only initialize in the top-level interactive shell.
      # Skip in nested subshells (devenv or nix-shell)
      # to prevent PTY proxy recursion loops, terminal lockups, and prompt conflicts.
      if [[ $- == *i* && -z "''${DEVENV_ROOT:-}" && -z "''${IN_NIX_SHELL:-}" ]]; then
        if [[ -r "${pkgs.blesh}/share/blesh/ble.sh" ]]; then
          source "${pkgs.blesh}/share/blesh/ble.sh" --noattach
        elif [[ -r "$HOME/.local/share/blesh/ble.sh" ]]; then
          source "$HOME/.local/share/blesh/ble.sh" --noattach
        elif [[ -r /usr/share/blesh/ble.sh ]]; then
          source /usr/share/blesh/ble.sh --noattach
        fi

        if type ble-face >/dev/null 2>&1; then
          ble-face auto_complete='fg=242,bg=,underline'
        fi

        # Performance optimizations to prevent lag:
        if type bleopt >/dev/null 2>&1; then
          bleopt complete_auto_delay=200
          bleopt highlight_timeout_sync=0
          bleopt char_width_mode=emacs
          # Exclude slow WSL Windows mount paths if running under WSL
          if grep -qsi Microsoft /proc/version 2>/dev/null; then
            ble/path#remove-glob PATH '/mnt/*'
          fi
        fi
      fi

      # Flatline (underline) cursor in terminal
      printf '\e[4 q'

      # Terminal bell off
      set +o notify
      [[ $- == *i* ]] && bind 'set bell-style none'

      # Sync history between simultaneous terminal sessions
      PROMPT_COMMAND='history -a; history -n'

      ##### 2. User Paths & Core Environment #####
      export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$HOME/.local/bin:$HOME/bin:$HOME/.opencode/bin:$PATH"

      # SSH Agent (avoids duplicate processes)
      if [[ -z "$SSH_AUTH_SOCK" ]]; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
      fi

      ##### 3. Helper Functions #####
      mkcd() {
        mkdir -p "$1" && cd "$1" || return
      }

      # Smart Tmux wrapper: attaches to active primary session (0) if invoked
      # interactively without arguments, preventing redundant ghost single-pane sessions.
      tmux() {
        if [ $# -eq 0 ] && [ -t 0 ] && [ -z "''${TMUX:-}" ]; then
          command tmux attach -t 0 2>/dev/null || command tmux attach 2>/dev/null || command tmux new-session -s 0
        else
          command tmux "$@"
        fi
      }

      # Seamless Ollama container CLI passthrough
      ollama() {
        if [ -t 0 ] && [ -t 1 ]; then
          podman exec -it local-ollama ollama "$@"
        else
          podman exec -i local-ollama ollama "$@"
        fi
      }

      ##### 4. Python SSL Certificate Bundle (if present) #####
      if python3 -c "import certifi" >/dev/null 2>&1; then
        CERT_PATH=$(python3 -m certifi)
        export SSL_CERT_FILE="''${CERT_PATH}"
        export REQUESTS_CA_BUNDLE="''${CERT_PATH}"
      fi

      ##### 5. Deduplicate PATH entries #####
      export PATH=$(printf "%s" "$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++')

      ##### 6. Local overrides (~/.bashrc.local) #####
      # Place machine-specific aliases, private API keys, custom tokens, and employer settings here.
      # This file is ignored by Git, preserved across Home Manager updates, and takes effect immediately.
      [[ -f ~/.bashrc.local ]] && source ~/.bashrc.local

      ##### 7. Direnv & Starship Shell Integration #####
      # Initialized BEFORE ble-attach so ble.sh captures the styled Starship prompt immediately on startup
      if command -v direnv >/dev/null 2>&1; then
        eval "$(direnv hook bash)"
      fi

      if [[ $TERM != "dumb" ]] && command -v starship >/dev/null 2>&1; then
        eval "$(starship init bash --print-full-init)"
        # Pre-render prompt once so $PS1 is populated before ble-attach captures it
        type starship_precmd >/dev/null 2>&1 && starship_precmd
      fi

      ##### 8. Attach ble.sh at the very end of interactive session #####
      if [[ $- == *i* && -z "''${DEVENV_ROOT:-}" && -z "''${IN_NIX_SHELL:-}" ]] && type ble-attach >/dev/null 2>&1; then
        ble-attach
      fi
    '';
  };
}

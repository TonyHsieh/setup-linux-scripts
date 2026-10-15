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
    };

    initExtra = ''
      ##### 1. ble.sh (Bash Line Editor) Integration #####
      if [[ $- == *i* ]]; then
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
      # Place private API keys, custom tokens, and employer settings here
      [[ -f ~/.bashrc.local ]] && source ~/.bashrc.local

      ##### 7. Attach ble.sh at the very end of interactive session #####
      if [[ $- == *i* ]] && type ble-attach >/dev/null 2>&1; then
        ble-attach
      fi
    '';
  };
}

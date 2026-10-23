{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shell = "${pkgs.bashInteractive}/bin/bash";
    terminal = "screen-256color";
    escapeTime = 0;
    mouse = true;
    keyMode = "vi";
    historyLimit = 100000;
    baseIndex = 1;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
    ];

    extraConfig = ''
      # Default window geometry for headless/detached sessions (e.g. continuum auto-restore)
      # Provides ample virtual canvas so large tiled layouts (e.g. 346x79) are never rejected
      set -g default-size 350x90

      # Automatically re-balance / expand tiled layout when client attaches
      set-hook -g client-attached 'select-layout -E'

      # Start pane index at 1
      setw -g pane-base-index 1

      # Window renaming
      set -g automatic-rename on
      set -g allow-rename on

      # Vi-style copy mode selection bindings
      unbind [
      bind [ copy-mode -e
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi V send -X select-line

      # Portable clipboard integration
      # Default fallback (xclip)
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard -in"
      bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection clipboard -in"

      # Wayland Linux override
      if-shell "[ -n \"$WAYLAND_DISPLAY\" ]" \
        'bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"; \
         bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "wl-copy"'

      # macOS override
      if-shell "[ -x /usr/bin/pbcopy ]" \
        'bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"; \
         bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"'

      # WSL override (Windows clipboard)
      if-shell 'grep -qsi Microsoft /proc/version' \
        'bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "/mnt/c/Windows/System32/clip.exe"; \
         bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "/mnt/c/Windows/System32/clip.exe"'

      # Vim-like pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Vim-like pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Status bar styling
      set -g status-position bottom
      set -g status-bg colour235
      set -g status-fg colour136
      set -g status-left "#[fg=colour40] #S "
      set -g status-right "#[fg=colour244]%Y-%m-%d %H:%M "

      # Reload tmux config shortcut (supports Home Manager XDG path)
      bind r if-shell "[ -f ~/.config/tmux/tmux.conf ]" \
        "source-file ~/.config/tmux/tmux.conf; display-message '~/.config/tmux/tmux.conf reloaded'" \
        "source-file ~/.tmux.conf; display-message '~/.tmux.conf reloaded'"

      # ble.sh cursor style & escape passthrough compatibility
      set -g cursor-style underline
      set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'
      set -g allow-passthrough on
    '';
  };
}

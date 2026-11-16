{ pkgs, ... }:

{
  # Editor Engine: Declarative Neovim with hermetic tooling
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
    withRuby = false;
    withPython3 = true;

    # Hermetically scope C compiler & build tools to Neovim's internal PATH
    # This fulfills nvim-treesitter requirements (gcc, gnumake, tree-sitter, curl, tar)
    # without polluting the global user environment, strictly preserving Prime Directive 2.
    extraPackages = with pkgs; [
      gcc
      gnumake
      tree-sitter
      curl
      gnutar
      ripgrep
      fd
    ];
  };
}

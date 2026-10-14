{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  # Deploy our custom starship.toml configuration
  xdg.configFile."starship.toml".source = ../dotfiles/starship.toml;
}

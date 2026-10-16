{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = false; # Handled explicitly in shell.nix before ble-attach
  };

  # Deploy our custom starship.toml configuration
  xdg.configFile."starship.toml".source = ../dotfiles/starship.toml;
}

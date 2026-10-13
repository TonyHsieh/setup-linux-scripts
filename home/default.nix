{ pkgs, lib, isWSL ? false, ... }:

{
  imports = [
    ./packages.nix
    ./shell.nix
    ./starship.nix
    ./tmux.nix
    ./git.nix
    ./ai-agents.nix
  ] ++ lib.optional isWSL ./wsl.nix;

  # Enable Home Manager and Direnv
  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Common Environment Variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    GOPATH = "$HOME/go";
  };

  # Home Manager release state version
  home.stateVersion = "24.11";

  # Configure rootless Podman search registries
  xdg.configFile."containers/registries.conf".text = ''
    unqualified-search-registries = ["docker.io"]
  '';

  # Deploy Tier 2 Local Container Mesh to ~/.local/share/local-services
  xdg.dataFile."local-services/docker-compose.yml".source = ../local-services/docker-compose.yml;
  xdg.dataFile."local-services/justfile".source = ../local-services/justfile;
  xdg.dataFile."local-services/traefik/dynamic.yml".source = ../local-services/traefik/dynamic.yml;
}

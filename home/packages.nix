{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Core CLI & Navigation
    git
    curl
    wget
    ripgrep
    jq
    yq-go
    bottom
    btop
    fzf
    bat
    eza
    fd

    # Cloud, Kubernetes & Secret Tooling
    kubectl
    kubernetes-helm
    fluxcd
    k9s
    kind
    sops
    age

    # Task Runners & Local Infrastructure
    just
    mkcert
    devenv
    postgresql

    # Editor Engine (Option A: Neovim stable managed via Nix)
    neovim

    # Bash Line Editor
    blesh
  ];
}

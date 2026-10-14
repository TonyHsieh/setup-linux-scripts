{
  description = "Cross-Platform Declarative Developer Environment & Devenv Ecosystem";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, home-manager, devenv, systems, ... }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      # 1. Reusable Devenv Module (Phase 4)
      devenvModules.common = import ./modules/devenv-common.nix;

      # 2. Project Flake Templates
      templates = {
        default = {
          path = ./templates/devenv-starter;
          description = "Standard devenv project starter with common linting and toolchains";
        };
        node = {
          path = ./templates/node;
          description = "Node.js (v22), TypeScript, pnpm, and Biome";
        };
        python = {
          path = ./templates/python;
          description = "Python 3.12 with uv fast package manager and ruff";
        };
        rust = {
          path = ./templates/rust;
          description = "Rust toolchain with clippy, rustfmt, and rust-analyzer";
        };
        kubernetes = {
          path = ./templates/kubernetes;
          description = "Kubernetes & CKAD study stack (kubectl, minikube, helm, k9s, exam aliases)";
        };
        ckad = {
          path = ./templates/kubernetes;
          description = "Alias for kubernetes template";
        };
      };

      # 3. User Home Manager Configurations across your machines
      homeConfigurations = {
        # 1. WSL2 Ubuntu (User: tonyh, Home: /home/tonyh)
        "wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          extraSpecialArgs = { inherit inputs; isWSL = true; };
          modules = [
            ./home/default.nix
            {
              home.username = "tonyh";
              home.homeDirectory = "/home/tonyh";
            }
          ];
        };

        # 2. CachyOS / Arch Linux (User: thsieh01, Home: /home/thsieh01)
        "cachyos" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          extraSpecialArgs = { inherit inputs; isWSL = false; };
          modules = [
            ./home/default.nix
            {
              home.username = "thsieh01";
              home.homeDirectory = "/home/thsieh01";
            }
          ];
        };

        # 3. macOS Darwin (User: thsieh01, Home: /Users/thsieh01)
        "darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."aarch64-darwin";
          extraSpecialArgs = { inherit inputs; isWSL = false; };
          modules = [
            ./home/default.nix
            ./home/darwin.nix
            {
              home.username = "thsieh01";
              home.homeDirectory = "/Users/thsieh01";
            }
          ];
        };
      };
    };
}

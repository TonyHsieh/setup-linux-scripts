{
  description = "Geoffrey Huntley Agent Sandbox Environment (Safe Git Guardrails)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, devenv, systems, ... }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem (system: {
        default = devenv.lib.mkShell {
          inherit inputs;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (import ./overlay.nix)
            ];
          };
          modules = [
            ./devenv.nix
          ];
        };
      });
    };
}

{ pkgs, lib, ... }:

{
  # Shared utilities exposed in all project devenv shells
  packages = with pkgs; [
    git
    jq
    yq-go
    ripgrep
    just
    sops
  ];

  # Pre-commit quality checks
  pre-commit.hooks = {
    nixpkgs-fmt.enable = true;
    trailing-whitespace-fixer.enable = true;
    end-of-file-fixer.enable = true;
    check-yaml.enable = true;
    check-json.enable = true;
  };

  # Shell banner and environment protection
  enterShell = ''
    if [ -n "''${CONDA_PREFIX:-}" ]; then
      echo "⚠️ Warning: Active Conda environment detected ('$CONDA_PREFIX')."
      echo "   Conda libraries can conflict with Nix packages. Please run 'conda deactivate'."
    fi
    echo "❄️ Devenv workspace active ($(basename "$PWD"))"
  '';
}

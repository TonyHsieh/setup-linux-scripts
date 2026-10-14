{ pkgs, lib, ... }:

{
  # Python stack with uv package manager
  languages.python = {
    enable = true;
    uv.enable = true;
  };

  packages = with pkgs; [
    ruff # Blazingly fast linter & code formatter
    git
    jq
  ];

  enterShell = ''
    echo "🐍 Python $(python3 --version 2>/dev/null) | uv ready!"
  '';
}

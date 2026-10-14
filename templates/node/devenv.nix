{ pkgs, lib, ... }:

{
  # Node.js & TypeScript stack
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    pnpm.enable = true;
  };
  languages.typescript.enable = true;

  packages = with pkgs; [
    biome # Fast formatter & linter
    git
    jq
  ];

  enterShell = ''
    echo "⚡ Node.js $(node --version 2>/dev/null || echo '22') | TypeScript ready!"
  '';
}

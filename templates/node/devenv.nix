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
    # Auto-sync dependencies if package.json exists, or display helpful guidance
    if [ -f package.json ]; then
      echo "📦 Syncing dependencies from package.json via pnpm..."
      pnpm install --prefer-offline 2>/dev/null || pnpm install
    else
      echo "⚠️  Warning: No 'package.json' found."
      echo "   💡 Best practice is to initialize your Node project: run 'pnpm init'."
      echo "   Whenever 'package.json' is created or saved, direnv will auto-sync dependencies!"
    fi

    echo "⚡ Node.js $(node --version 2>/dev/null || echo '22') | pnpm $(pnpm --version 2>/dev/null) | TypeScript ready!"
    echo "💡 Quality check: 'biome check .' | Format: 'biome format --write .'"
  '';
}

{ pkgs, lib, ... }:

{
  # Node.js & TypeScript stack with Effect-TS ecosystem support
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    pnpm.enable = true;
  };
  languages.typescript.enable = true;

  packages = with pkgs; [
    biome # Fast formatter & linter
    tsx   # Direct TypeScript execution engine
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
      echo "   💡 Initialize your TypeScript & Effect project:"
      echo "      1. run 'pnpm init'"
      echo "      2. run 'pnpm add effect @effect/schema @effect/platform'"
      echo "      3. run 'pnpm add -D typescript @types/node tsx biome vitest'"
      echo "   Whenever 'package.json' or 'pnpm-lock.yaml' is created, direnv will auto-sync!"
    fi

    echo "✨ Node.js $(node --version 2>/dev/null || echo '22') | pnpm $(pnpm --version 2>/dev/null) | TypeScript + Effect ready!"
    echo "💡 Quality check: 'biome check .' | Run script: 'tsx src/index.ts' | Test: 'vitest run'"
  '';
}

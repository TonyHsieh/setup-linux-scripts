{ pkgs, lib, ... }:

{
  # Go toolchain
  languages.go.enable = true;

  packages = with pkgs; [
    gopls
    golangci-lint
    delve
    gotools
    git
    jq
  ];

  enterShell = ''
    # Auto-sync dependencies if go.mod exists, or display helpful guidance
    if [ -f go.mod ]; then
      echo "📦 Syncing Go module dependencies from go.mod..."
      go mod download 2>/dev/null || echo "💡 Run 'go mod tidy' to synchronize module requirements."
    else
      echo "⚠️  Warning: No 'go.mod' found."
      echo "   💡 Initialize your Go module: run 'go mod init <module-path>'."
      echo "   Whenever 'go.mod' or 'go.sum' is created, direnv will automatically watch it!"
    fi

    echo "🐹 Go $(go version 2>/dev/null | awk '{print $3}') | gopls $(gopls version 2>/dev/null | head -n1 | awk '{print $2}') ready!"
    echo "💡 Quality check: 'golangci-lint run' | Test: 'go test ./...' | Debug: 'dlv'"
  '';
}

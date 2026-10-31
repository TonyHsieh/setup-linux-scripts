{ pkgs, lib, ... }:

{
  # Rust toolchain
  languages.rust.enable = true;

  packages = with pkgs; [
    rust-analyzer
    cargo-watch
    cargo-edit
    git
    jq
  ];

  enterShell = ''
    # Auto-check project if Cargo.toml exists, or display helpful guidance
    if [ -f Cargo.toml ]; then
      echo "📦 Validating Cargo project dependencies..."
      cargo check --quiet 2>/dev/null || echo "💡 Run 'cargo check' to inspect compilation status."
    else
      echo "⚠️  Warning: No 'Cargo.toml' found."
      echo "   💡 Initialize a new Rust project: run 'cargo init' (binary) or 'cargo init --lib' (library)."
      echo "   Whenever 'Cargo.toml' is created or modified, direnv will automatically watch it!"
    fi

    echo "🦀 Rust $(rustc --version 2>/dev/null) | Cargo $(cargo --version 2>/dev/null | awk '{print $2}') ready!"
    echo "💡 Tooling available: cargo-watch ('cargo watch -x check'), cargo-edit ('cargo add'), rust-analyzer"
  '';
}

{ pkgs, lib, ... }:

{
  # Rust toolchain with WebAssembly compilation target
  languages.rust = {
    enable = true;
    channel = "stable";
    targets = [ "wasm32-unknown-unknown" ];
  };

  packages = with pkgs; [
    wasm-pack
    wasm-bindgen-cli
    binaryen # wasm-opt, wasm-merge
    wabt     # wasm2wat, wat2wasm
    rust-analyzer
    cargo-watch
    cargo-edit
    git
    jq
  ];

  enterShell = ''
    # Auto-validate project if Cargo.toml exists, or display helpful guidance
    if [ -f Cargo.toml ]; then
      echo "📦 Validating Rust/WASM project dependencies..."
      cargo check --target wasm32-unknown-unknown --quiet 2>/dev/null || echo "💡 Run 'cargo check --target wasm32-unknown-unknown' to inspect compilation status."
    else
      echo "⚠️  Warning: No 'Cargo.toml' found."
      echo "   💡 Initialize a new Rust/WASM project:"
      echo "      • Full WebAssembly library: run 'wasm-pack new <project-name>'"
      echo "      • Standard crate: run 'cargo init --lib'"
      echo "   Whenever 'Cargo.toml' or 'Cargo.lock' is created or modified, direnv will auto-sync!"
    fi

    echo "🦀 Rust $(rustc --version 2>/dev/null) [wasm32-unknown-unknown] | wasm-pack $(wasm-pack --version 2>/dev/null) ready!"
    echo "💡 WASM build: 'wasm-pack build --target web' | Test: 'wasm-pack test --node' | Optimize: 'wasm-opt -O3'"
  '';
}

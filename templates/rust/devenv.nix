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
    echo "🦀 Rust $(rustc --version 2>/dev/null) | Cargo ready!"
  '';
}

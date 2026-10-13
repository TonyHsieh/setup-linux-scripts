{ pkgs, lib, ... }:

{
  # Import common standards from setup-linux-scripts (or local relative path)
  # imports = [ ... ];

  packages = with pkgs; [
    git
    jq
    ripgrep
  ];

  enterShell = ''
    echo "🚀 Entering project developer environment!"
  '';
}

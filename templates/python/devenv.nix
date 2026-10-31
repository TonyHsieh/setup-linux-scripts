{ pkgs, lib, ... }:

{
  # Python stack with uv package manager & writable virtualenv
  languages.python = {
    enable = true;
    venv = {
      enable = true;
      # Uncomment if you want devenv to automatically install requirements on shell entry:
      # requirements = ./requirements.txt;
    };
    uv.enable = true;
  };

  # Native libraries & build tools for Python wheels (PyTorch, sentencepiece, etc.)
  packages = with pkgs; [
    ruff
    git
    jq
    stdenv.cc.cc.lib
    zlib
  ];

  enterShell = ''
    echo "🐍 Python $(python3 --version 2>/dev/null) | uv ready!"
    echo "💡 Virtualenv active at: $VIRTUAL_ENV"
    echo "   • Fast pip: 'uv pip install <package>' (or standard 'pip install')"
    echo "   • Sync requirements: 'uv pip install -r requirements.txt'"
  '';
}

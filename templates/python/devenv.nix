{ pkgs, lib, ... }:

{
  # Python stack with uv package manager & writable virtualenv
  languages.python = {
    enable = true;
    venv.enable = true;
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
    # Ensure standard pip executable is present in virtualenv for notebook compatibility
    if [ ! -f "$VIRTUAL_ENV/bin/pip" ]; then
      uv pip install pip --quiet 2>/dev/null || true
    fi

    # Auto-sync dependencies if requirements.txt exists, or display helpful best-practice guidance
    if [ -f requirements.txt ]; then
      echo "📦 Syncing dependencies from requirements.txt via uv..."
      uv pip install -r requirements.txt
    elif [ -f pyproject.toml ]; then
      echo "📦 Syncing project dependencies from pyproject.toml via uv..."
      uv sync
    else
      echo "⚠️  Warning: No 'requirements.txt' found."
      echo "   💡 Best practice is to declare your Python dependencies in 'requirements.txt'."
      echo "   Whenever you create one, direnv will automatically detect and install them via uv!"
    fi

    echo "🐍 Python $(python3 --version 2>/dev/null) | uv ready!"
    echo "💡 Virtualenv active at: $VIRTUAL_ENV"
    echo "   • Fast pip: 'uv pip install <package>' (or standard 'pip install')"
    echo "   • Sync requirements: Auto-managed on save via direnv"
  '';
}

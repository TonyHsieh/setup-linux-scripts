#!/usr/bin/env bash
# ==============================================================================
# remove-lunarvim.sh
# Purpose: Completely remove LunarVim and clean up Neovim directories for a fresh install
# ==============================================================================
set -euo pipefail

echo "==> Starting LunarVim cleanup"

# 1. Remove LunarVim binary
if [ -f "$HOME/.local/bin/lvim" ]; then
  echo "   - Removing lvim binary..."
  rm -f "$HOME/.local/bin/lvim"
fi

# 2. Remove LunarVim folders
LUNARVIM_DIRS=(
  "$HOME/.local/share/lunarvim"
  "$HOME/.cache/lvim"
  "$HOME/.config/lvim"
)

for dir in "${LUNARVIM_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    echo "   - Removing $dir..."
    rm -rf "$dir"
  fi
done

# 3. Remove Neovim state/cache/config directories to prevent conflicts with new installs (e.g. LazyVim)
NEOVIM_DIRS=(
  "$HOME/.config/nvim"
  "$HOME/.local/share/nvim"
  "$HOME/.local/state/nvim"
  "$HOME/.cache/nvim"
)

for dir in "${NEOVIM_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    echo "   - Removing Neovim directory: $dir..."
    rm -rf "$dir"
  fi
done

echo "✓ LunarVim has been successfully removed and Neovim directories cleared!"
echo "👉 You can now run install-dev-env.sh to install a fresh copy of LazyVim."

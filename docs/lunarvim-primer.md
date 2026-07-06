# LunarVim Primer for Experienced Vim Users

[LunarVim](https://www.lunarvim.org/) is a fast, opinionated IDE layer built on top of Neovim. It configures sensible defaults and integrates modern features (like LSP, tree-sitter, fuzzy-finding, and autocompletion) using Lua-based configuration.

This primer helps experienced Vim/Neovim users quickly get up to speed with the keybindings, configuration, and workflows of LunarVim.

---

## 🚀 Core Keybindings

LunarVim uses the **`<Space>`** key as its `<leader>` key. Most IDE-like functions are mapped under it.

### 1. General & File Navigation
*   `SPC e` - Toggle file explorer tree (**NvimTree**).
*   `SPC f` - Fuzzy-find files in the current repository (**Telescope**).
*   `SPC s t` - Live grep (fuzzy-search text inside files) across the codebase.
*   `SPC s h` - Search Vim help tags.
*   `SPC c` - Close (delete) the current buffer without closing the split.

### 2. LSP & Code Navigation (Go-to commands)
Standard LSP navigation commands map to standard Vim symbols but are enhanced by the language server:
*   `gd` - Go to definition.
*   `gI` - Go to implementation.
*   `gr` - Show all references (opens a Telescope search panel).
*   `K` - Show hover documentation/tooltips for the symbol under cursor.
*   `SPC l a` - Open LSP code actions (auto-import, fix diagnostic, etc.).
*   `SPC l r` - Rename symbol under cursor (updates all occurrences in code).
*   `[d` / `]d` - Go to previous/next diagnostic warning/error.

### 3. Buffer Navigation (Tabs)
Instead of opening actual Vim tabs (which are separate window layouts), LunarVim treats open buffers as tabs at the top of the editor:
*   `Shift + l` (or `L`) - Go to next buffer (right).
*   `Shift + h` (or `H`) - Go to previous buffer (left).
*   `SPC b p` - Open interactive buffer selector.

### 4. Splitting & Terminal
*   `Ctrl + \` - Toggle a floating shell terminal within the editor.
*   `SPC w v` or `:vsplit` - Split window vertically.
*   `SPC w h` or `:split` - Split window horizontally.
*   `Ctrl + h/j/k/l` - Navigate between splits.

---

## 🛠️ Configuration & Customization

All LunarVim configuration is stored in **`~/.config/lvim/config.lua`**. 
*(This directory is preserved when running `uninstall-dev-env.sh` to ensure you never lose your work).*

### 1. Setting Editor Options
You can configure standard Vim options using Lua syntax:
```lua
-- Enable line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Tab settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
```

### 2. Keymaps
Add custom keymaps using LunarVim's wrapper:
```lua
-- Normal mode: mapping 'jk' to Esc
lvim.keys.insert_mode["jk"] = "<ESC>"

-- Map 'leader + p' to paste without overwriting default register
lvim.keys.normal_mode["<leader>p"] = [["_dP]]
```

### 3. Adding Plugins (via `lazy.nvim`)
You can add extra plugins by adding items to the `lvim.plugins` list:
```lua
lvim.plugins = {
  {
    "tpope/vim-surround",
  },
  {
    "github/copilot.vim",
    config = function()
      -- Copilot config here
    end,
  }
}
```

---

## 🔄 Lazy & Mason (Under the Hood)

LunarVim abstracts package and LSP installations:
*   **`:Lazy`**: Opens the plugin manager interface. Here you can update, clean, and profile your plugins.
*   **`:Mason`**: Opens the LSP/Linter/Formatter manager GUI. From here, you can install language servers (like Pyright, gopls, tsserver) with a single click or command.

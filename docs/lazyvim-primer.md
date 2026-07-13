# LazyVim Primer for Developers

LazyVim is a modern, fast, and modular Neovim configuration framework. It provides a "batteries-included" IDE experience while keeping the configuration clean and easy to customize.

---

## 📁 Directory Structure

All configuration files are located in `~/.config/nvim/`. The structure is designed to separate options, keymaps, and plugin specifications:

```txt
~/.config/nvim/
├── init.lua                # Entry point (requires lua/config/lazy.lua)
└── lua/
    ├── config/
    │   ├── keymaps.lua     # Custom keymaps (loaded after plugins)
    │   ├── lazy.lua        # Lazy.nvim setup & distribution configuration
    │   └── options.lua     # Vim options (line numbers, tabstop, etc.)
    └── plugins/
        └── example.lua     # Add your custom plugin specifications here
```

---

## ⚡ Core Features & Plugins Included

LazyVim integrates several top-tier plugins to deliver a cohesive IDE experience out of the box:

*   **Package Manager (`lazy.nvim`)**: Fast plugin loader with a beautiful visual UI (`:Lazy`).
*   **Fuzzy Finder (`telescope.nvim` / `fzf-lua`)**: Fuzzy searches files, buffers, regex queries, and LSP references.
*   **File Explorer (`neo-tree.nvim`)**: Sidebar directory navigation (`:Neotree`).
*   **LSP Client (`nvim-lspconfig` + `mason.nvim`)**: Automatic LSP, linter, and formatter installation and configuration.
*   **Formatting (`conform.nvim`)**: Auto-formatting on save for supported filetypes.
*   **Command Helper (`which-key.nvim`)**: Visual popup showing available keybindings when you press a prefix key (like `<space>`).

---

## ⌨️ Essential Keyboard Shortcuts

The **Leader Key** is configured to **`<Space>`** by default.

### File & Buffer Operations
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `<leader>e` or `<leader>fe` | Toggle File Tree | Open/close Neo-tree sidebar explorer |
| `<leader>ff` | Find Files | Fuzzy search files in the current project |
| `<leader>fF` | Find Files (Root) | Fuzzy search files from the Git root directory |
| `<leader>sg` | Live Grep | Regex text search across project files |
| `<leader>bb` | Switch Buffer | Fuzzy list and switch between active buffers |
| `<leader>bd` | Delete Buffer | Close the current file buffer safely |
| `[b` / `]b` | Prev / Next Buffer | Quick cycle between open buffers |

### LSP & Code Navigation
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `gd` | Go to Definition | Jump to the source definition of the symbol |
| `gr` | Go to References | Search all usages/references of the symbol |
| `gI` | Go to Implementation| Jump to interface implementation |
| `K` | Hover Doc | View signature and docstring details under cursor |
| `<leader>ca` | Code Action | Trigger LSP refactoring / imports fixes |
| `<leader>cr` | Rename Symbol | Rename the symbol globally across project |
| `<leader>cf` | Format Document | Run formatter manually (usually formats on save) |
| `[d` / `]d` | Prev / Next Diagnostic | Jump between warnings and syntax errors |

### Git Integration
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `<leader>gg` | LazyGit | Opens the full LazyGit terminal UI inside Neovim |
| `[c` / `]c` | Prev / Next Hunk | Jump between uncommitted git changes |
| `<leader>ghd` | Git Diff Hunk | View a diff of changes for the current block |

---

## 🛠️ Configuring Languages via `:LazyExtras`

LazyVim features a built-in modular extension system called **Extras**. You can toggle complete environments (LSPs, formatters, linters, debuggers) using a visual UI:

1. Type **`:LazyExtras`** inside Neovim.
2. Scroll to the desired language or tool (e.g., `lang.typescript`, `lang.go`, `lang.python`, `formatting.prettier`).
3. Press **`x`** to enable/disable it.
4. LazyVim will automatically install all necessary binaries in the background via Mason.

---

## 🔌 Adding Custom Plugins

To add your own plugins or customize existing ones, create a new `.lua` file inside `~/.config/nvim/lua/plugins/`. LazyVim will automatically load any file placed here.

### Example: Adding `mini.surround` and Customizing `tokyonight`
Create `~/.config/nvim/lua/plugins/custom.lua`:

```lua
return {
  -- 1. Configure Tokyonight theme style
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "storm", -- Change style to storm, night, or day
    },
  },

  -- 2. Add a new plugin (e.g., mini.surround for text surrounds)
  {
    "echasnovski/mini.surround",
    opts = {
      mappings = {
        add = "gsa", -- Add surrounding characters
        delete = "gsd", -- Delete surrounding characters
        find = "gsf", -- Find surrounding characters
      },
    },
  },
}
```

#!/usr/bin/env bash
# ==============================================================================
# setup-starship.sh
# Purpose: Idempotently set up Starship prompt configuration on CachyOS / Linux
# ==============================================================================
set -euo pipefail

echo "==> Setting up Starship configuration..."

mkdir -p ~/.config

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
DEST_FILE="$HOME/.config/starship.toml"
LOCAL_CONFIG="$SCRIPT_DIR/starship.toml"

# Function to safely deploy starship.toml
deploy_config() {
  local content_source="$1" # 'file' or 'heredoc'
  
  if [[ -f "$DEST_FILE" ]]; then
    if [[ "$content_source" == "file" ]]; then
      if cmp -s "$LOCAL_CONFIG" "$DEST_FILE"; then
        echo "   ✓ ~/.config/starship.toml is already up-to-date (no changes needed)"
        return 0
      fi
    else
      # For heredoc, we check diff against a temporary file
      local tmp_file
      tmp_file=$(mktemp)
      write_default_config "$tmp_file"
      if cmp -s "$tmp_file" "$DEST_FILE"; then
        echo "   ✓ ~/.config/starship.toml is already up-to-date (no changes needed)"
        rm -f "$tmp_file"
        return 0
      fi
      rm -f "$tmp_file"
    fi
    
    echo "   ⚠️ Found existing ~/.config/starship.toml. Creating backup at ~/.config/starship.toml.bak"
    cp "$DEST_FILE" "${DEST_FILE}.bak"
  fi

  if [[ "$content_source" == "file" ]]; then
    cp "$LOCAL_CONFIG" "$DEST_FILE"
    echo "   ✓ Successfully copied $LOCAL_CONFIG to $DEST_FILE"
  else
    write_default_config "$DEST_FILE"
    echo "   ✓ Successfully wrote default configuration to $DEST_FILE"
  fi
}

write_default_config() {
  local target="$1"
  cat << 'EOF' > "$target"
### from https://dev.to/stamperlabs/customizing-macos-terminal-with-starship-like-a-pro-2geb

"$schema" = 'https://starship.rs/config-schema.json'

format = """
$time$directory$git_branch$git_status$fill$aws$nodejs$java$gradle$custom
$os$character
"""

[fill]
symbol = ' '

############################################################
# Time / Date (with seconds)
############################################################
[time]
disabled = false
format = '[$time]($style) '
time_format = "%Y-%m-%d %H:%M:%S"
style = "dimmed white"

[directory]
format = '[ $path ]($style)[$read_only]($read_only_style)'
style = 'bg:blue'
read_only_style = 'bg:red'
truncate_to_repo = true
truncation_length = 3

[git_branch]
format = '[ $symbol$branch ]($style)'
style = 'bg:green'

[git_status]
format = '[$all_status$ahead_behind](bg:green)'
conflicted = '[ = ](bg:yellow bold)'
ahead = '[ ⇡ ](bg:yellow bold)'
behind = '[ ⇣ ](bg:yellow bold)'
diverged = '[ ⇕ ](bg:yellow bold)'
up_to_date = ''
untracked = '[ ? ](bg:yellow bold)'
stashed = '[ \$ ](bg:yellow bold)'
modified = '[ ! ](bg:yellow bold)'
staged = '[ + ](bg:yellow bold)'
renamed = '[ » ](bg:yellow bold)'
deleted = '[ ✘ ](bg:yellow bold)'
typechanged = ""

[aws]
format = '[ $symbol $profile $region ]($style)'
symbol = ' '

[nodejs]
format = '[ $symbol$version ](bg:cyan bold)'
version_format = '${raw}'

[custom.npm]
command = "npm -v"
when = "test -f package.json"
format = "[ $symbol $output ](bg:yellow bold)"
symbol = ''

[custom.yarn]
command = "yarn -v"
when = "test -f yarn.lock"
format = "[ $symbol $output ](bg:cyan bold)"
symbol = ''

[custom.pnpm]
command = "pnpm -v"
when = "test -f pnpm-lock.yaml"
format = "[ $symbol $output ](bg:cyan bold)"
symbol = ''

[java]
format = '[ $symbol $version ]($style)'
version_format = '${raw}'
style = 'bg:red bold'
symbol = '󰅶'

[gradle]
format = '[ $symbol $version ](bg:cyan bold)'
version_format = '${raw}'
symbol = ''

[custom.jreleaser]
command = "jreleaser --version 2>&1 | grep '^jreleaser ' | awk '{print $2}'"
when = "test -f jreleaser.yml"
format = '[ Jr: $output ](bg:red bold)'

[os]
format = '[$symbol ]($style)'
disabled = false

[os.symbols]
Macos = '󰀵'
Arch = '󰣇'
CachyOS = ''
Linux = '🐧'

[character]
success_symbol = "[❯](bold default)"
error_symbol = '[✗](bold red) '
EOF
}

# Deploy the configuration
if [[ -f "$LOCAL_CONFIG" ]]; then
  deploy_config "file"
else
  deploy_config "heredoc"
fi

echo "==> Starship config deployed successfully!"
echo "==> Restart your terminal or run: exec bash"

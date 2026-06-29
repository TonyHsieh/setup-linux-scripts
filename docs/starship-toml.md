# 🛠️ Starship TOML Configuration (`starship.toml`) Features

This document provides a detailed breakdown of the custom configuration defined in [`starship.toml`](file:///home/tonyh/_Projects/setup-linux-scripts/starship.toml), which is deployed to `~/.config/starship.toml`.

---

## 📐 Prompt Layout

The prompt is structured into two lines using a right-aligned format powered by the `$fill` module:

```toml
format = """
$time$directory$git_branch$git_status$fill$aws$nodejs$java$gradle$custom
$os$character
"""
```

- **Line 1 (Status & Context)**: Left-aligned info (Time, Directory, Git branch, Git status) and Right-aligned info (AWS, Node.js, Java, Gradle, Custom package managers/tools).
- **Line 2 (Shell Interaction)**: Operating System icon and the active prompt character.

---

## 📦 Configured Modules & Features

### 🕒 Time (`[time]`)
- **Format**: `[YYYY-MM-DD HH:MM:SS]`
- **Style**: Dimmed white.
- **Purpose**: Provides a timestamp for when the command prompt was rendered, helping track runtime history.

### 📁 Directory (`[directory]`)
- **Style**: Blue background (`bg:blue`).
- **Read-Only Style**: Red background (`bg:red`).
- **Truncation**: Truncates paths to the repository root. Shows a maximum of `3` directory segments.

### 🌿 Git Branch (`[git_branch]`)
- **Style**: Green background (`bg:green`).
- **Purpose**: Displays the active Git branch name alongside the branch symbol.

### 📊 Git Status (`[git_status]`)
- **Style**: Green background (`bg:green`) for the status container, with indicators highlighted in yellow bold.
- **Custom State Indicators**:
  - `=` Conflicted
  - `⇡` Ahead of upstream
  - `⇣` Behind upstream
  - `⇕` Diverged from upstream
  - `?` Untracked files
  - `$` Stashed changes
  - `!` Modified files
  - `+` Staged files
  - `»` Renamed files
  - `✘` Deleted files

### ☁️ AWS Cloud (`[aws]`)
- **Symbol**: `` (Cloud icon)
- **Format**: Displays the active profile name and current AWS region.

### 🟢 NodeJS (`[nodejs]`)
- **Style**: Cyan bold background (`bg:cyan bold`).
- **Format**: Shows the current local Node.js version.

### ☕ Java (`[java]`)
- **Symbol**: `󰅶` (Java cup icon)
- **Style**: Red bold background (`bg:red bold`).
- **Format**: Shows the active Java version.

### 🐘 Gradle (`[gradle]`)
- **Symbol**: ``
- **Style**: Cyan bold background (`bg:cyan bold`).
- **Format**: Shows the active Gradle version.

### 💻 Operating System (`[os]`)
- **Status**: Enabled.
- **Icons**:
  - **macOS**: `󰀵`
  - **Arch Linux**: `󰣇`
  - **CachyOS**: ``
  - **Generic Linux**: `🐧`

### ⚡ Prompt Character (`[character]`)
- **Success Symbol**: `❯` (Bold default)
- **Error Symbol**: `✗` (Bold red) - triggers when the last command returns a non-zero exit code.

---

## 🔧 Custom Command Detectors (`[custom]`)

These detectors execute lightweight background commands to identify the exact package managers or tools present in the current workspace.

| Tool | Trigger File | Command Executed | Icon | Style |
| :--- | :--- | :--- | :--- | :--- |
| **npm** | `package.json` | `npm -v` | `` | Yellow bold background |
| **yarn** | `yarn.lock` | `yarn -v` | `` | Cyan bold background |
| **pnpm** | `pnpm-lock.yaml` | `pnpm -v` | `` | Cyan bold background |
| **jreleaser** | `jreleaser.yml` | `jreleaser --version` (filtered) | `Jr:` | Red bold background |

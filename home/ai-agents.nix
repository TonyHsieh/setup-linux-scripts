{ pkgs, ... }:

{
  # Declarative OpenCode skills & commands
  xdg.configFile."opencode/skills/agy/SKILL.md".source = ../dotfiles/opencode/skills/agy/SKILL.md;
  xdg.configFile."opencode/commands/agy.md".source = ../dotfiles/opencode/commands/agy.md;
}

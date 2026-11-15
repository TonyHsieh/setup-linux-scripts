{ pkgs, inputs ? {}, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  llmPkgs = if inputs ? llm-agents && inputs.llm-agents ? packages && inputs.llm-agents.packages ? ${system}
    then inputs.llm-agents.packages.${system}
    else {};
in
{
  home.packages = [
    # Declarative GitHub Copilot CLI from nixpkgs
    pkgs.github-copilot-cli
  ] ++ pkgs.lib.optionals (llmPkgs != {}) [
    llmPkgs.opencode
    llmPkgs.hermes-agent
    llmPkgs.claude-code
    llmPkgs.herdr
    llmPkgs.antigravity-cli
  ];

  # Declarative OpenCode skills & commands
  xdg.configFile."opencode/skills/agy/SKILL.md".source = ../dotfiles/opencode/skills/agy/SKILL.md;
  xdg.configFile."opencode/commands/agy.md".source = ../dotfiles/opencode/commands/agy.md;
}

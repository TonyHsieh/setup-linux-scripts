{ pkgs, inputs ? {}, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  llmPkgs = if inputs ? llm-agents && inputs.llm-agents ? packages && inputs.llm-agents.packages ? ${system}
    then inputs.llm-agents.packages.${system}
    else {};

  # Temporary hotfix (tracked in AGENTS.md): hermes-agent-0.23.0 in numtide/llm-agents.nix
  # injects its Python deps via site.addsitedir() inside .hermes-wrapped, NOT via PYTHONPATH.
  # When Kanban spawns workers via bare `sys.executable -m hermes_cli.kanban_worker_client`,
  # those child Python processes lose all site-packages (websockets, ruamel.yaml, etc.).
  # Extracting the exact site-packages list from .hermes-wrapped into PYTHONPATH fixes every
  # missing module in one shot while preserving 100% of cache.numtide.com binary substitution.
  hermesAgentPatched =
    if llmPkgs ? hermes-agent then
      pkgs.symlinkJoin {
        name = "hermes-agent-kanban-pythonpath";
        paths = [ llmPkgs.hermes-agent ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          HERMES_PYTHONPATH="$(grep -oE '/nix/store/[a-zA-Z0-9._+-]+/lib/python[0-9.]+/site-packages' "${llmPkgs.hermes-agent}/bin/.hermes-wrapped" | paste -sd: -)"
          for bin in "$out"/bin/*; do
            if [ -f "$bin" ] && [ -x "$bin" ]; then
              rm "$bin"
              makeWrapper "${llmPkgs.hermes-agent}/bin/$(basename "$bin")" "$bin" \
                --suffix PYTHONPATH : "$HERMES_PYTHONPATH"
            fi
          done
        '';
      }
    else null;
in
{
  home.packages = [
    # Declarative GitHub Copilot CLI from nixpkgs
    pkgs.github-copilot-cli
  ] ++ pkgs.lib.optionals (llmPkgs != {}) ([
    llmPkgs.opencode
    llmPkgs.claude-code
    llmPkgs.herdr
    llmPkgs.antigravity-cli
  ] ++ pkgs.lib.optional (hermesAgentPatched != null) hermesAgentPatched);

  # Declarative OpenCode skills & commands
  xdg.configFile."opencode/skills/agy/SKILL.md".source = ../dotfiles/opencode/skills/agy/SKILL.md;
  xdg.configFile."opencode/commands/agy.md".source = ../dotfiles/opencode/commands/agy.md;
}

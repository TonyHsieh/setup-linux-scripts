# templates/agent-sandbox/overlay.nix
# Self-contained Geoffrey Huntley "Patch the Planet" (ghuntley/nix-demo) Safe Git Guardrail

final: prev: {
  # 1. CRITICAL GUARDRAIL: Keep build-time gitMinimal strictly unpatched
  gitMinimal = prev.gitMinimal;

  # 2. Instant Zero-Recompile Safe Git Wrapper
  # Intercepts force push, branch deletion, and +refspec overrides instantly
  safeGit = final.writeShellScriptBin "git" ''
    for arg in "$@"; do
      if [[ "$arg" =~ ^(-f|--force|--force-with-lease|--delete|-D)$ ]] || [[ "$arg" =~ \+refs/ ]]; then
        echo "🛑 NIX AGENT GUARDRAIL (Huntley Pattern): Destructive Git operation '$arg' blocked by policy." >&2
        exit 1
      fi
    done
    exec ${prev.git}/bin/git "$@"
  '';
}

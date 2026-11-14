# nix/overlays/agent-git.nix
# Geoffrey Huntley "Patch the Planet" (ghuntley/nix-demo) Agent Git Guardrails

final: prev: {
  # 1. CRITICAL GUARDRAIL: Keep build-time gitMinimal strictly unpatched!
  # If gitMinimal is modified, stdenv and low-level build tools trigger a rebuild of the entire world.
  gitMinimal = prev.gitMinimal;

  # 2. Source-Patched Git Derivation (Geoff Huntley compile-time C patch)
  # Disables --force, -f, and --force-with-lease directly in builtin/push.c.
  agentGit = prev.git.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../../third_party/git/001-disable-force-push.patch
    ];
    doCheck = false;
    doInstallCheck = false;
  });

  # 3. Instant Zero-Recompile Safe Git Wrapper
  # Intercepts force push, branch deletion, and +refspec overrides instantly without compilation delay.
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

{ pkgs, lib, ... }:

{
  # Geoffrey Huntley "Patch the Planet" (ghuntley/nix-demo) Agent Sandbox
  packages = with pkgs; [
    safeGit      # Intercepts and physically blocks git push --force / -f
    ripgrep
    fd
    jq
  ];

  # Strip host secrets from the agent's execution subshell
  env = {
    SSH_AUTH_SOCK = "";
    SOPS_AGE_KEY_FILE = "/dev/null";
    AWS_SECRET_ACCESS_KEY = "";
  };

  enterShell = ''
    echo "🛡️  Entered Geoffrey Huntley Agent Sandbox Environment."
    echo "👉 Policy: Destructive Git operations (force-push, delete) are strictly disabled."
  '';
}

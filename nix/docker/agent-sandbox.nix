# nix/docker/agent-sandbox.nix
# Declarative OCI Image for Geoffrey Huntley 3-Layer Agent Sandbox

{ pkgs ? import <nixpkgs> { }
, extraPackages ? [ ]
}:

let
  agentGitOverlay = import ../overlays/agent-git.nix;
  hardenedPkgs = pkgs.extend agentGitOverlay;
in
hardenedPkgs.dockerTools.buildLayeredImage {
  name = "agent-sandbox";
  tag = "latest";

  contents = with hardenedPkgs; [
    # Layer 1 Guardrails (Huntley Safe-Git)
    safeGit
    bashInteractive
    coreutils
    ripgrep
    fd
    jq
    curl
    cacert
    iana-etc
    tzdata
  ] ++ extraPackages;

  config = {
    Cmd = [ "${hardenedPkgs.bashInteractive}/bin/bash" ];
    WorkingDir = "/workspace";
    Env = [
      "PATH=/bin:${hardenedPkgs.safeGit}/bin:${hardenedPkgs.coreutils}/bin:${hardenedPkgs.ripgrep}/bin:${hardenedPkgs.jq}/bin:${hardenedPkgs.fd}/bin:${hardenedPkgs.curl}/bin"
      "SSL_CERT_FILE=${hardenedPkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "SSH_AUTH_SOCK="
      "SOPS_AGE_KEY_FILE=/dev/null"
      "AWS_SECRET_ACCESS_KEY="
      "HOME=/tmp/agent-home"
      "TERM=xterm-256color"
    ];
    Volumes = {
      "/workspace" = { };
      "/shared-kanban" = { };
    };
  };
}

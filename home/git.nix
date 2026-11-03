{ pkgs, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      alias = {
        s = "status";
        l = "log --oneline --decorate --graph";
        d = "diff";
        co = "checkout";
        br = "branch";
        ci = "commit";
      };

      init.defaultBranch = "main";
      pull.rebase = false;
      # Automatically set up remote tracking on first push so 'git push' works without -u / --set-upstream
      push.autoSetupRemote = true;
      core.editor = "nvim";
    };
  };
}

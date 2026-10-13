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
      core.editor = "nvim";
    };
  };
}

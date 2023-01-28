{ pkgs, config, flake, ... }:
{
  home.packages = [ pkgs.git-lfs ];

  programs.git = {
    package = pkgs.gitAndTools.gitFull;
    enable = true;
    userName = "Rodrigo Belem";
    userEmail = "rodrigo.belem@gmail.com";
    aliases = {
      b = "branch";
      co = "checkout";
      ci = "commit";
      cia = "commit --amend";
      graph = "log --decorate --oneline --graph";
      pu = "push";
      s = "status";
      st = "status";
    };
    lfs = { enable = true; };
    ignores = [ "*~" "*.swp" ".direnv" ];
    extraConfig = {
      # Make git faster for large repositories
      feature.manyFiles = true;
      init.defaultBranch = "main";
      credential.helper = "store --file ~/.git-credentials";
    };
  };
}


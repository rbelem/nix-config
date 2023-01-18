{ pkgs, config, ... }:
let
  # cli to update the sha256
  # nix-prefetch fetchFromGitHub --owner gpakosz --repo .tmux --rev 2cf4d9a10415f58612c1a387fbeb9c0efe79d751
  tmuxConfig = pkgs.fetchFromGitHub {
      owner = "gpakosz";
      repo = ".tmux";
      rev = "2cf4d9a10415f58612c1a387fbeb9c0efe79d751";
      sha256 = "sha256-bA0da2nIIEQUCtervsiZLNQ2V6+OizBr8Uqz94sGV1A=";
  };
in {
  programs.tmux = {
    enable = true;
  };

  home = {
    file = {
      ".tmux" = {
        recursive = true;
        source = tmuxConfig;
      };
      ".tmux.conf" = {
        source = "${tmuxConfig}/.tmux.conf";
      };
      ".tmux.conf.local" = {
        source = ./.tmux.conf.local;
      };
    };
  };

  programs.tmate = {
    enable = true;
    # FIXME: This causes tmate to hang.
    # extraConfig = config.xdg.configFile."tmux/tmux.conf".text;
  };
}

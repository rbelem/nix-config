{ config, pkgs, ... }: {
  imports = [
    ./bash
    ./neovim
    ./tmux
  ];

  home.packages = with pkgs; [
    exa
    jq
    lazygit
  ];
}

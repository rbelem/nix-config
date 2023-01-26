{ config, pkgs, ... }: {
  imports = [
    ./bash
    ./fzf
    ./neovim
    ./tmux
  ];

  home.packages = with pkgs; [
    exa
    jq
    lazygit
  ];
}

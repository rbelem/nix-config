{ config, pkgs, ... }: {
  imports = [
    ./neovim
    ./tmux
  ];
}

{ config, pkgs, ... }: {
  imports = [
    ./bash
    ./fzf
    ./git
    ./neovim
    ./tmux
  ];

  home.packages = with pkgs; [
    exa
    jq
    lazygit
    nix-prefetch
    nixos-option
  ];
}

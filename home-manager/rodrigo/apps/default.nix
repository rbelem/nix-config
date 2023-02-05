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

  programs.zoxide.enable = true;
  programs.zoxide.enableBashIntegration = true;
}

{ config, pkgs, ... }: {
  imports = [
    ./bash
    ./fzf
    ./git
    ./neovim
    ./tmux
  ];

  home.packages = with pkgs; [
    jq
    lazygit
    nix-prefetch
    nixos-option
  ];

  programs.exa.enable = true;
  programs.exa.enableAliases = true;

  programs.zoxide.enable = true;
  programs.zoxide.enableBashIntegration = true;
}

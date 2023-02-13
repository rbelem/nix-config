{ config, pkgs, ... }: {
  imports = [
    ./bash
    ./devbox
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

  programs.fzf.enable = true;
  programs.fzf.tmux.enableShellIntegration = true;

  programs.zoxide.enable = true;
  programs.zoxide.enableBashIntegration = true;
}

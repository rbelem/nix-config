{ pkgs, ... }: {
  home.packages = with pkgs; [
    devbox
  ];

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}

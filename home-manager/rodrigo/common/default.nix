{ config, pkgs, ... }: {
  imports = [
    ./fonts.nix
  ];

  home.packages = with pkgs; [
    wget
  ];
}

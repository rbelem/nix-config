{ config, pkgs, ... }: {
  imports = [
    ./fonts.nix
    ./starship.nix
  ];

  home.packages = with pkgs; [
    wget
  ];
}

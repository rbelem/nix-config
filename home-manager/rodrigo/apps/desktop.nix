{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    brave
    calibre
    discord
    element-desktop
    firefox
    google-chrome
    kate
    keybase-gui
    logseq
    thunderbird
  ];
}

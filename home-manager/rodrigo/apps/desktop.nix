{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    brave
    calibre
    discord
    element-desktop
    firefox
    galaxy-buds-client
    google-chrome
    kate
    keybase-gui
    logseq
    thunderbird
  ];
}

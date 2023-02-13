{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    ark
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
    signal-desktop
    thunderbird
  ];
}

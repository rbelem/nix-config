# Merlin web UI service configuration for RT-AX88U
{ pkgs, lib, ... }:

let
  mwu = pkgs.merlin-web-ui;
in {
  imports = [ ../../../modules/merlin-web-ui.nix ];

  services.merlin-webui = {
    enable = true;
    package = mwu.httpd;
    www = mwu.www;
    listenPort = 80;
    loglevel = "3";
  };

}

# Merlin web UI service configuration for RT-AX88U
{ pkgs, lib, ... }:

let
  mwu = pkgs.merlin-web-ui;
in {
  imports = [ ../../modules/merlin-web-ui.nix ];

  services.merlin-webui = {
    enable = true;
    package = mwu.httpd;
    www = mwu.www;
    listenPort = 80;
    loglevel = "3";
  };

  # Lighttpd fallback for static files (works without Merlin httpd)
  services.lighttpd = {
    enable = true;
    documentRoot = "${mwu.www}/www";
    port = 8080;
    enableModules = [ "mod_redirect" ];
  };
}

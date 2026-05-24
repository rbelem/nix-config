{ config, pkgs, lib, ... }: {
  services.fprintd = {
    enable = true;
    package = pkgs.fprintd.override {
      libfprint = pkgs.libfprint-canvasbio-cb2000;
    };
  };

  # Enable fingerprint for login and sudo
  security.pam.services.login.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
}

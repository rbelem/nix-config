{ config, pkgs, lib, ... }: {
  services.fprintd = {
    enable = true;
    package = pkgs.fprintd.override {
      libfprint = pkgs.libfprint-canvasbio-cb2000;
    };
  };

  # Enable fingerprint for login and sudo. The login manager inherits
  # pam_fprintd from the "login" substack (plasmalogin's PAM rules are
  # explicit and reduce to `auth substack login`, so login.fprintAuth is
  # what carries fingerprint into the greeter; setting fprintAuth on
  # plasmalogin itself is a no-op — its explicit rules replace the
  # option-driven ones). The Plasma lock screen needs NO entry: upstream's
  # plasma6 module handles it via a separate "kde-fingerprint" service, and
  # enabling fprintAuth on "kde" itself blocks password login — see
  # nixpkgs#239770.
  security.pam.services.login.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
}

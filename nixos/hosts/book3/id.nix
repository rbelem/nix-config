{
  config,
  pkgs,
  lib,
  ...
}:
{
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

  # pam_fprintd's default slot (after `unix`, before `unix-early`) makes it
  # the FIRST PAM conversation. SDDM's greeter (0.21, omarchy theme) submits
  # the typed password only against a password prompt, so under
  # fingerprint-first the typed password never reaches pam_unix and password
  # login dies — only the finger works (book3, 2026-10-26 debugging). Move
  # fprintd behind the password capture, and make a CORRECT password end the
  # stack: `sufficient` alone is not short-circuit — PAM still walks further,
  # so fprintd would prompt for the finger right after Enter even on a good
  # password. With `success=done` on unix, a correct password logs in
  # immediately; wrong password falls through to the finger. Relative order,
  # per the nixpkgs warning against fixed order constants.
  security.pam.services.login.rules.auth."unix".control = lib.mkForce "[success=done default=ignore]";
  security.pam.services.login.rules.auth."unix".order =
    config.security.pam.services.login.rules.auth."gnome_keyring".order + 10;
  security.pam.services.login.rules.auth.fprintd.order =
    config.security.pam.services.login.rules.auth."unix".order + 10;
}

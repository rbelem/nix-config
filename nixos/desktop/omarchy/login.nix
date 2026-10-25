# Omarchy's boot splash, packaged, and the greeter's avatar.
#
# NixOS collects a theme from `<package>/share/plymouth/themes/<name>`, copies
# the selected one into the initrd at /etc/plymouth/themes, and rewrites the
# `/nix/store/.../share/plymouth/themes` paths it finds there. Upstream's
# omarchy.plymouth names the Arch install location instead, so without the
# substitution below the initrd copy keeps an ImageDir that does not exist:
# plymouth loads no image, the script draws nothing, and the splash is blank
# for the length of the boot.
#
# The greeter's PAM service is built from `login` in all four phases, so the
# keyring unlock is services.gnome.gnome-keyring.enable's
# security.pam.services.login.enableGnomeKeyring rather than anything local.
# What the greeter does take from here is its avatar.
{ pkgs }:

let
  # The theme is copied out of the shell package rather than named as the
  # theme package itself. boot.plymouth.themePackages joins a package to the
  # system closure whole, and the shell is not 180 KiB.
  plymouthTheme = pkgs.runCommand "omarchy-plymouth-theme" { } ''
    theme=$out/share/plymouth/themes/omarchy
    install -d "$theme"
    cp -r ${pkgs.omarchy-shell}/share/omarchy/default/plymouth/. "$theme"
    chmod -R u+w "$theme"
    substituteInPlace "$theme/omarchy.plymouth" \
      --replace-fail '/usr/share/plymouth/themes/omarchy' "$theme"
  '';

  # SDDM reads a user's avatar at `<FacesDir>/<name>.face.icon`
  # (src/greeter/UserModel.cpp), and the NixOS module sets FacesDir to
  # /run/current-system/sw/share/sddm/faces, the system profile that
  # environment.systemPackages builds. So this package's share/sddm/faces is
  # where the greeter looks, and the theme's own logo.png is the avatar.
  #
  # The name is a literal because this module is called with `inherit pkgs`
  # alone, which leaves config.users.users out of scope.
  faceUser = "rodrigo";

  faceIcon = pkgs.runCommand "omarchy-sddm-face" { } ''
    install -D -m644 ${./sddm-theme/omarchy/logo.png} \
      $out/share/sddm/faces/${faceUser}.face.icon
  '';
in
{
  boot.plymouth.themePackages = [ plymouthTheme ];

  environment.systemPackages = [ faceIcon ];
}

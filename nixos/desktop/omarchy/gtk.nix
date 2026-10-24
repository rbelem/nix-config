# The GTK, icon and cursor side of an Omarchy theme.
#
# Upstream applies this with gsettings rather than by writing a gtk.css
# (bin/omarchy-theme-set-gnome): the theme's colour mode selects an Adwaita
# variant, and its accent lives in the icon theme that icons.theme names.
# These are the same keys, taken from the selected theme instead of from
# ~/.local/state/omarchy/current/theme.
#
# gsettings writes the user's dconf database, which is per-user state, so the
# keys are applied by a user service on every login. Setting a key twice is
# harmless — dconf stores the value, not a log of writes — so re-login and
# repeated logins are idempotent.
#
# This returns a configuration fragment rather than a module, because the
# settings depend on the selected theme, and a module cannot be imported on a
# condition that reads `config`. default.nix folds it in with mkMerge, which
# merges per option and so does not displace the theme service or the package
# list the rest of the desktop defines.
{ lib, pkgs, theme, mode, iconTheme }:
let
  dark = mode != "light";

  # Adwaita-dark carries the dark colours and prefer-dark tells GTK4 and
  # libadwaita to follow it. Upstream sets exactly this pair.
  gtkTheme = if dark then "Adwaita-dark" else "Adwaita";
  colorScheme = if dark then "prefer-dark" else "prefer-light";

  # Nixarchy's cursor pairing: the ice cursor on a dark theme, the classic one
  # on a light theme.
  cursorTheme = if dark then "Bibata-Modern-Ice" else "Bibata-Modern-Classic";

  # The icon sets yaru-theme ships. Upstream's Arch package also carries
  # Yaru-gray and Yaru-grey, which nixpkgs does not, so the palettes naming one
  # of those get the blue set rather than an icon theme that is not installed.
  yaruColours = [
    "blue" "magenta" "olive" "prussiangreen" "purple" "red" "sage"
    "wartybrown" "yellow"
  ];
  shippedIcons =
    [ "Yaru" "Yaru-dark" ]
    ++ lib.concatMap (colour: [ "Yaru-${colour}" "Yaru-${colour}-dark" ]) yaruColours;

  icon = if lib.elem iconTheme shippedIcons then iconTheme else "Yaru-blue";
in
{
  # Clients that read XCURSOR_* rather than gsettings — Wayland clients without
  # a settings portal, and toolkits that start before the service runs — need
  # the cursor in their environment as well.
  environment.sessionVariables = {
    XCURSOR_THEME = cursorTheme;
    XCURSOR_SIZE = "24";
  };

  # The themes the keys name have to be on disk for a client to find them.
  environment.systemPackages = [ pkgs.bibata-cursors pkgs.yaru-theme ];

  systemd.user.services.omarchy-gtk = {
    description = "Apply the ${theme} Omarchy GTK, icon and cursor settings";
    wantedBy = [ "graphical-session.target" ];
    # gsettings ships with glib, which a user service does not inherit.
    path = [ pkgs.glib ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    script = ''
      set -eu

      # gsettings needs a user bus. Reached from a chroot or a boot with no
      # graphical session there is none, and the next login runs this again.
      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        exit 0
      fi

      gsettings set org.gnome.desktop.interface color-scheme "${colorScheme}"
      gsettings set org.gnome.desktop.interface gtk-theme "${gtkTheme}"
      gsettings set org.gnome.desktop.interface icon-theme "${icon}"
      gsettings set org.gnome.desktop.interface cursor-theme "${cursorTheme}"
      gsettings set org.gnome.desktop.interface cursor-size 24
    '';
  };
}

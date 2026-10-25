# Sets the wallpaper to the background of the selected Omarchy theme.
#
# Upstream draws the background in its QuickShell background plugin from the
# staged current/background link, which no theme-set run stages here, so
# swaybg is a layer-shell client instead: it covers every output Hyprland
# has and exits with the session.
#
# This returns a configuration fragment rather than a module, for the reason
# gtk.nix gives: the wallpaper is the selected theme's, and a module cannot be
# imported on a condition that reads `config`. default.nix folds it in with
# mkMerge.
#
# The image path is part of the unit, so changing the theme rewrites the unit
# and the switch restarts it.
{ lib, pkgs, theme }:

let
  # Upstream applies the first background in sorted order when a theme is set
  # (choose_theme_background in omarchy-theme-set), so only that one is
  # vendored. `theme` is the theme name, as in cfg.theme.
  dir = ./themes/${theme}/backgrounds;

  wallpaper = dir + "/${builtins.head (lib.sort (a: b: a < b) (builtins.attrNames (builtins.readDir dir)))}";
in
{
  systemd.user.services.omarchy-wallpaper = {
    description = "Set the Omarchy wallpaper";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.swaybg}/bin/swaybg -m fill -i ${wallpaper}";
      Restart = "on-failure";
    };
  };
}

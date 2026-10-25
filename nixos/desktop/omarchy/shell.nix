# Upstream Omarchy's QuickShell shell: bar, dock, menu, OSD and lock screen.
#
# The tree is pkgs/omarchy-shell's whole-tree copy at OMARCHY_PATH, and
# bin/ rides the session PATH unwrapped. What the shell spawns by bare name
# is installed here; anything it degrades without (pactl events, xkbcli key
# names, the omarchy-platform files) is left out and noted in the README.
#
# This returns a configuration fragment rather than a module, for the reason
# gtk.nix gives: it is imported on a condition that reads `config`.
# default.nix folds it in with mkMerge.
{ lib, pkgs }:

{
  # The tree the shell reads, and its commands. sessionVariables reach the
  # Hyprland session the same way XCURSOR_THEME already does in gtk.nix.
  environment.sessionVariables.OMARCHY_PATH = "${pkgs.omarchy-shell}/share/omarchy";

  environment.systemPackages = with pkgs; [
    # The shell itself: omarchy, omarchy-launch-shell, omarchy-shell and
    # the omarchy-menu-* commands the keybindings invoke.
    omarchy-shell
    # The QML runner, and the `qs` client the omarchy-shell IPC falls back to.
    quickshell
    # omarchy-shell's fast-path IPC. A missing socat binary fails every call
    # as "not responding" instead of falling through to qs.
    socat
    # Menu payloads, clipboard capture, theme and i18n helpers.
    jq
    # omarchy-menu-select encodes its menu payload with JSON::PP from core.
    perl
    # Volume and microphone reads and writes go through wpctl.
    wireplumber
    # Brightness keys and the OSD spawn bare brightnessctl.
    brightnessctl
    # Desktop-entry launching, after the uwsm-app patch in the package.
    gtk3
    # The input-method indicator interpreter.
    python3
  ];
}

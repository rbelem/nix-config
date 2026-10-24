# The session daemons niri does not start.
#
# Omarchy's Hyprland stack gets these from its own session: an agent to answer
# polkit prompts, a daemon to draw notifications, and an idle timer that locks
# the screen. niri starts the compositor and nothing else, so the session
# starts them.
#
# This returns a configuration fragment rather than a module, for the reason
# gtk.nix gives: it is imported on a condition that reads `config`.
# default.nix folds it in with mkMerge.
{ lib, pkgs, swaylock }:
{
  systemd.user.services.omarchy-polkit-agent = {
    description = "Polkit authentication agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.hyprpolkitagent}/bin/hyprpolkitagent";
      Restart = "on-failure";
    };
  };

  # No configuration file: mako's defaults are grey on a translucent background
  # with light text, which reads correctly on Adwaita-dark.
  systemd.user.services.omarchy-notifications = {
    description = "Notification daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.mako}/bin/mako";
      Restart = "on-failure";
    };
  };

  # The lock runs before the blank, so coming back to the screen needs the
  # password rather than a keypress. before-sleep covers a lid close, which
  # logind suspends on.
  #
  # There is no idle suspend: this machine runs builds and VMs for hours.
  #
  # The unit is named omarchy-idle rather than swayidle so a stay-awake toggle
  # has one unit to stop.
  systemd.user.services.omarchy-idle = {
    description = "Idle lock and screen blank";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    # The timers call `niri`, which is on the PATH the session imported into
    # the user manager and not on the minimal one a user unit gets by default.
    enableDefaultPath = false;
    serviceConfig = {
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle \
          timeout 300 '${swaylock} -f' \
          timeout 600 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors' \
          before-sleep '${swaylock} -f'
      '';
      Restart = "on-failure";
    };
  };
}

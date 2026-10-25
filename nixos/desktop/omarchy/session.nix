# The session daemons Hyprland does not start.
#
# Omarchy's Hyprland stack gets these from its own session: an agent to answer
# polkit prompts and an idle timer that locks the screen. Notifications need
# no daemon: the QuickShell shell draws them itself. Hyprland starts the
# compositor and nothing else, so the session starts them.
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
      # Upstream installs the agent to libexec, not bin: it is D-Bus
      # activated rather than run from PATH.
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
    };
  };

  # No notification daemon: upstream's QuickShell shell draws notifications
  # itself, and a second daemon would draw every one twice.

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
    # The timers call `hyprctl`, which is on the PATH the session imported
    # into the user manager and not on the minimal one a user unit gets by
    # default.
    enableDefaultPath = false;
    serviceConfig = {
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle \
          timeout 300 '${swaylock} -f' \
          timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on' \
          before-sleep '${swaylock} -f'
      '';
      Restart = "on-failure";
    };
  };
}

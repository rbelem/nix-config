{ config, pkgs, lib, ... }:
{
  systemd.services.state-snapshot = {
    description = "Snapshot OpenTofu state to Bitwarden";

    serviceConfig = {
      Type = "oneshot";
      User = "root";

      # ansible writes BW_SESSION=<token> here at deploy time
      EnvironmentFile = "/etc/agent/bw_session.env";

      # Proper concurrency lock — flock wraps ExecStart
      ExecStart = "${pkgs.flock}/bin/flock /var/lock/state-snapshot.lock /opt/assistant/scripts/snapshot-state.sh";

      StandardOutput = "journal";
      StandardError = "journal";

      # Fail fast if BW is locked or network is down
      TimeoutStartSec = "5min";
    };

    # No wantedBy here — the timer triggers it. Adding wantedBy would cause
    # an extra run at boot, which we don't want.
  };

  systemd.timers.state-snapshot = {
    description = "Periodic OpenTofu state snapshot to Bitwarden";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      # Hourly is conservative; tighten later if BW API rate limits bite.
      OnCalendar = "hourly";
      # Run if missed (e.g., system was off)
      Persistent = true;
      # Randomize to avoid thundering herd
      RandomizedDelaySec = "5min";
    };
  };
}

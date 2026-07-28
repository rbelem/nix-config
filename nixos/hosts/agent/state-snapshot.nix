{ config, pkgs, lib, ... }:
let
  snapshotScript = "/home/rodrigo/Workspace/rbelem/assistant/scripts/snapshot-state.sh";
  bwSessionFile = "/root/.bw_session_token";
in
{
  systemd.services.state-snapshot = {
    description = "Snapshot OpenTofu state to Bitwarden";
    
    # Run as root so we can read /root/.bw_session_token
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      
      # Snapshot script reads BW_SESSION from the file at runtime
      EnvironmentFile = bwSessionFile;
      
      ExecStart = snapshotScript;
      
      # Don't spam journald on success
      StandardOutput = "journal";
      StandardError = "journal";
      
      # Hard timeout: if BW is locked / network down, fail fast
      TimeoutStartSec = "5min";
      
      # Locking: prevent concurrent snapshots
      ExecStartPre = "-${pkgs.coreutils}/bin/sh -c '${pkgs.flock}/bin/flock -n /var/lock/state-snapshot.lock echo locked || exit 0'";
    };
    
    # Required by systemd-timer below
    wantedBy = [ "multi-user.target" ];
  };

  systemd.timers.state-snapshot = {
    description = "Periodic OpenTofu state snapshot to Bitwarden";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      # Hourly is conservative; user can tune
      OnCalendar = "hourly";
      # Run if missed (e.g., system was off)
      Persistent = true;
      # Randomize to avoid thundering herd
      RandomizedDelaySec = "5min";
    };
  };
}

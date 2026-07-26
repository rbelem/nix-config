{ config, runtime-config, ... }:
let
  cfg = runtime-config;
in
{
  # Restic backup to Hetzner Object Storage (S3-compatible)
  services.restic.backups = {
    daily = {
      initialize = true;
      paths = [
        "/var/lib/rancher/k3s"
      ];
      repository = "s3:${cfg.backup.s3.endpoint}/${cfg.backup.s3.bucket}";
      environmentFile = config.sops.secrets.restic-env.path;
      passwordFile = config.sops.secrets.restic-password.path;
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 3"
      ];
    };
  };
}

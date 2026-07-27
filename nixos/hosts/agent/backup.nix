{ config, runtime-config, ... }:
let
  cfg = runtime-config;
in
{
  # Secrets sourced from /etc/restic/env (written by ansible/secrets.yml
  # from Bitwarden). RESTIC_PASSWORD + AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
  # all live in that one file.
  services.restic.backups = {
    daily = {
      initialize = true;
      paths = [ "/var/lib/rancher/k3s" ];
      repository = "s3:${cfg.backup.s3.endpoint}/${cfg.backup.s3.bucket}";
      environmentFile = "/etc/restic/env";
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

{ ... }: {
  # Restic backup to OVH Object Storage
  services.restic.backups = {
    daily = {
      initialize = true;
      paths = [
        "/var/lib/rancher/k3s"
      ];
      repository = "s3:https://s3.eu-west-par.io.REDACTED-OVH-DOMAIN/REDACTED-BUCKET";
      environmentFile = "/etc/restic/env";
      passwordFile = "/etc/restic/password";
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

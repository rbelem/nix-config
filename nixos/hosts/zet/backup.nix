{ config, runtime-config, lib, ... }:
let
  backup = runtime-config.backup or null;
in
{
  # Secrets sourced from /etc/restic/env (written by ansible/secrets.yml
  # from Bitwarden). RESTIC_PASSWORD + AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
  # all live in that one file.
  #
  # Restic backups were deferred 2026-07-27 (backup bucket removed from
  # tofu/main.tf; fetch_vault.sh no longer emits runtime-config.backup).
  # The module is enabled only when the config is present again.
  services.restic.backups = lib.mkIf (backup != null) {
    daily = {
      initialize = true;
      paths = [ "/var/lib/rancher/k3s" ];
      repository = "s3:${backup.s3.endpoint}/${backup.s3.bucket}";
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

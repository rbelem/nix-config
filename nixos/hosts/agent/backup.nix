{ config, runtime-config, ... }:
let
  cfg = runtime-config;
in
{
  # Restic backup disabled for first deploy — requires sops-nix secrets (password +
  # AWS creds) which aren't provisioned yet. Re-enable by:
  # 1. Generate age key on VPS (nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key)
  # 2. Encrypt secrets/restic-{env,password}.yaml stubs with `sops --encrypt --in-place`
  # 3. Uncomment the services.restic.backups block below
  #
  # services.restic.backups = {
  #   daily = {
  #     initialize = true;
  #     paths = [ "/var/lib/rancher/k3s" ];
  #     repository = "s3:${cfg.backup.s3.endpoint}/${cfg.backup.s3.bucket}";
  #     environmentFile = config.sops.secrets.restic-env.path;
  #     passwordFile = config.sops.secrets.restic-password.path;
  #     timerConfig = {
  #       OnCalendar = "daily";
  #       Persistent = true;
  #       RandomizedDelaySec = "1h";
  #     };
  #     pruneOpts = [
  #       "--keep-daily 7"
  #       "--keep-weekly 4"
  #       "--keep-monthly 3"
  #     ];
  #   };
  # };
}

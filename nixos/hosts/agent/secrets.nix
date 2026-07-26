{ ... }: {
  # sops-nix for Nix-level secrets (k3s token, restic, caddy, etc.)
  sops = {
    # defaultSopsFile intentionally omitted: per-secret sopsFile paths are used.
    # See ./secrets/*.yaml. To re-enable a shared default, run `sops update-keys-secrets
    # secrets.yaml` and uncomment.
    age = {
      # Generate key: nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/etc/sops/age/key.txt";
    };

    # Restic backup credentials (H5)
    secrets.restic-env = {
      sopsFile = ./secrets/restic-env.yaml;
      mode = "0600";
    };
    secrets.restic-password = {
      sopsFile = ./secrets/restic-password.yaml;
      mode = "0600";
    };

    # Caddy DNS-01 challenge credentials (H6)
    secrets.caddy-env = {
      sopsFile = ./secrets/caddy-env.yaml;
      mode = "0600";
    };
  };
}

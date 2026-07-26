{ ... }: {
  # sops-nix disabled for first deploy — secret stubs need to be encrypted with
  # `sops --encrypt --in-place` once an age key is provisioned on the VPS. To
  # re-enable: generate age key (nix run nixpkgs#ssh-to-age -- -i
  # /etc/ssh/ssh_host_ed25519_key), encrypt the ./secrets/*.yaml stubs in place,
  # then uncomment the sops block below.
  #
  # sops = {
  #   age = {
  #     sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  #     keyFile = "/etc/sops/age/key.txt";
  #   };
  #   secrets.restic-env = {
  #     sopsFile = ./secrets/restic-env.yaml;
  #     mode = "0600";
  #   };
  #   secrets.restic-password = {
  #     sopsFile = ./secrets/restic-password.yaml;
  #     mode = "0600";
  #   };
#   secrets.caddy-env = {
#     sopsFile = ./secrets/caddy-env.yaml;
#     mode = "0600";
#   };
  # };
}

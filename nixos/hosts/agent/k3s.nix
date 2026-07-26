{ pkgs, ... }: {
  # k3s — single-node Kubernetes
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable traefik"
      "--disable servicelb"
      "--write-kubeconfig-mode 644"
    ];
  };

  # Make kubectl available
  environment.systemPackages = [ pkgs.kubectl ];

  # Allow k3s API access
  networking.firewall.allowedTCPPorts = [ 6443 ];
}

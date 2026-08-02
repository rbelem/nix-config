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

  # Make kubectl/helm/helmfile available (assistant deploy runs helmfile sync VPS-side)
  environment.systemPackages = [ pkgs.kubectl pkgs.kubernetes-helm pkgs.helmfile ];

  # Allow k3s API access
  networking.firewall.allowedTCPPorts = [ 6443 ];
}

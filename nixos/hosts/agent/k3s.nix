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
  # python3 (with kubernetes lib) is required by ansible: bootstrap/secrets-apply/
  # deploy/update playbooks + kubernetes.core.k8s module.
  environment.systemPackages = [
    pkgs.kubectl pkgs.kubernetes-helm pkgs.helmfile
    (pkgs.python3.withPackages (ps: [ ps.kubernetes ]))
  ];

  # Allow k3s API access
  networking.firewall.allowedTCPPorts = [ 6443 ];
}

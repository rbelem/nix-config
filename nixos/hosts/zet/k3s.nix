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

  # Make kubectl/helm/helmfile available (the zet repo's deploy runs helmfile sync VPS-side)
  # python3 (with kubernetes lib) is required by ansible: bootstrap/secrets-apply/
  # deploy/update playbooks + kubernetes.core.k8s module.
  environment.systemPackages = [
    pkgs.kubectl pkgs.kubernetes-helm pkgs.helmfile
    (pkgs.python3.withPackages (ps: [ ps.kubernetes ]))
  ];

  # Allow k3s API access
  networking.firewall.allowedTCPPorts = [ 6443 ];

  # Deploy phases (deploy.sh helmfile/kubectl) rsync into /opt/k8s as rodrigo.
  systemd.tmpfiles.rules = [ "d /opt/k8s 0755 rodrigo users -" ];
}

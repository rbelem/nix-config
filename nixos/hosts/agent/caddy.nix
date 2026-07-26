{ pkgs, config, runtime-config, ... }:
let
  cfg = runtime-config;
  domain = cfg.domain;
in
{
  # Caddy reverse proxy with Porkbun DNS-01 wildcard TLS
  # Caddy runs on the host and proxies to k8s services via NodePort.
  # Wildcard cert for *.${domain} obtained via Porkbun DNS challenge.
  services.caddy = {
    enable = true;

    # Porkbun API credentials for DNS-01 challenge (provisioned via sops-nix, H6)
    environmentFile = config.sops.secrets.caddy-env.path;

    # Global config: DNS-01 challenge via Porkbun, wildcard cert
    extraConfig = ''
      (dns01) {
        tls {
          dns porkbun {env.PORKBUN_API_KEY} {env.PORKBUN_SECRET_API_KEY}
        }
      }
    '';

    # Hermes — AI agent backend (k8s NodePort 30080)
    virtualHosts."hermes.${domain}".extraConfig = ''
      import dns01
      reverse_proxy localhost:30080
    '';

    # Uptime Kuma — monitoring dashboard (k8s NodePort 30001)
    virtualHosts."status.${domain}".extraConfig = ''
      import dns01
      reverse_proxy localhost:30001
    '';

    # n8n — Tailscale-gated
    virtualHosts."n8n.${domain}".extraConfig = ''
      import dns01
      @tailscale remote_ip 100.64.0.0/10 100.128.0.0/10
      handle @tailscale {
        reverse_proxy localhost:30002
      }
      handle {
        respond "Access denied" 403
      }
    '';

    # Zitadel — Tailscale-gated
    virtualHosts."auth.${domain}".extraConfig = ''
      import dns01
      @tailscale remote_ip 100.64.0.0/10 100.128.0.0/10
      handle @tailscale {
        reverse_proxy localhost:30003
      }
      handle {
        respond "Access denied" 403
      }
    '';
  };

  # Allow HTTP/HTTPS
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

{ pkgs, config, runtime-config, ... }:
let
  cfg = runtime-config;
  domain = cfg.domain;
in
{
  # Caddy reverse proxy for k8s NodePorts.
  # Wildcard TLS via Porkbun DNS-01 was planned but is disabled for first deploy:
  #   1. Stock nixpkgs caddy lacks the porkbun DNS plugin (need caddy-with-plugins
  #      package built with github.com/caddy-dns/porkbun)
  #   2. sops-nix secrets disabled (no PORKBUN_API_KEY)
  # Re-enable both together: provision sops age key, encrypt caddy-env.yaml stub,
  # then uncomment the global extraConfig + `import dns01` per-vhost below AND
  # switch services.caddy.package to a custom caddy-with-plugins derivation.
  services.caddy = {
    enable = true;

    # Hermes — AI agent backend (k8s NodePort 30080)
    virtualHosts."hermes.${domain}".extraConfig = ''
      reverse_proxy localhost:30080
    '';

    # Uptime Kuma — monitoring dashboard (k8s NodePort 30001)
    virtualHosts."status.${domain}".extraConfig = ''
      reverse_proxy localhost:30001
    '';

    # n8n — Tailscale-gated
    virtualHosts."n8n.${domain}".extraConfig = ''
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
      @tailscale remote_ip 100.64.0.0/10 100.128.0.0/10
      handle @tailscale {
        reverse_proxy localhost:30003
      }
      handle {
        respond "Access denied" 403
      }
    '';
  };

  # Allow HTTP/HTTPS (no TLS yet — see comment above)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

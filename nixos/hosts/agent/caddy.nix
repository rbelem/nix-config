{ pkgs, config, runtime-config, ... }:
let
  cfg = runtime-config;
  domain = cfg.domain;
in
{
  services.caddy = {
    enable = true;
    # No third-party plugins — use default caddy with HTTP-01 challenge
    # (port 80 is open). DNS A records are managed by OpenTofu (tofu/dns.tf,
    # Cloudflare provider). The legacy Porkbun acme_dns block was removed
    # because the domain nameservers are Cloudflare, not Porkbun.
    package = pkgs.caddy;

    # Secrets environment file kept for forward compatibility.
    environmentFile = "/etc/caddy/env";

    # ACME uses Caddy's default HTTP-01 challenge (port 80 is open; A records
    # managed by Tofu). Log level is the module default (logFormat = "level ERROR").

    virtualHosts = {
      # Hermes — AI agent (k3s NodePorts 30080 API / 30090 dashboard)
      "hermes.${domain}".extraConfig = ''
        # OpenAI-compatible API server (port 8642 via NodePort 30080)
        handle /v1/* {
          reverse_proxy localhost:30080
        }
        # Web dashboard (port 9119 via NodePort 30090)
        handle {
          reverse_proxy localhost:30090
        }
      '';

      # Uptime Kuma — monitoring (k3s NodePort 30001)
      "status.${domain}".extraConfig = ''
        reverse_proxy localhost:30001
      '';

      # n8n — Tailscale-gated (k3s NodePort 30002)
      "n8n.${domain}".extraConfig = ''
        @tailscale remote_ip 100.64.0.0/10 100.128.0.0/10
        handle @tailscale {
          reverse_proxy localhost:30002
        }
        handle {
          respond "Access denied" 403
        }
      '';

      # Zitadel — Tailscale-gated (k3s NodePort 30003)
      "auth.${domain}".extraConfig = ''
        @tailscale remote_ip 100.64.0.0/10 100.128.0.0/10
        handle @tailscale {
          reverse_proxy localhost:30003
        }
        handle {
          respond "Access denied" 403
        }
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

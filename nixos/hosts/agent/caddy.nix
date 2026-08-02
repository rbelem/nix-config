{ pkgs, config, runtime-config, ... }:
let
  cfg = runtime-config;
  domain = cfg.domain;

  # Caddy with Porkbun DNS-01 plugin for wildcard TLS certificates.
  # Plugin version pinned to latest available (v0.3.1 as of 2026-07); hash must
  # match the actual build output. To regenerate: replace hash with
  # lib.fakeHash, run `nix build .#nixosConfigurations.agent.config.services.caddy.package`
  # and paste the "got:" hash from the error message.
  caddy-with-plugins = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/porkbun@v0.3.1" ];
    hash = "sha256-CjL8dMdnsiawaPiQGRvL3he4Ydd3nIbQs6tBWMwUbaw=";
  };
in
{
  services.caddy = {
    enable = true;
    package = caddy-with-plugins;

    # Secrets sourced from /etc/caddy/env (written by ansible/secrets.yml
    # from Bitwarden vault item "Porkbun API Key"). PORKBUN_API_KEY and
    # PORKBUN_SECRET_API_KEY are injected into the caddy systemd unit.
    environmentFile = "/etc/caddy/env";

    # Global ACME config — DNS-01 via Porkbun for wildcard cert.
    # {env.VAR} is Caddy's runtime env placeholder (subdirective names per
    # caddy-dns/porkbun README: api_key + api_secret_key).
    globalConfig = ''
      acme_dns porkbun {
        api_key {env.PORKBUN_API_KEY}
        api_secret_key {env.PORKBUN_SECRET_API_KEY}
      }
    '';

    virtualHosts = {
      # Hermes — AI agent (k3s NodePort 30080)
      "hermes.${domain}".extraConfig = ''
        reverse_proxy localhost:30080
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

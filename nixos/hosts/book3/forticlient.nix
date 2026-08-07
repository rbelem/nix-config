{ pkgs, lib, ... }: let
  # FortiGate SSL VPN connection for work.
  # openfortivpn is used instead of the official FortiClient because the
  # proprietary binary has unresolved compatibility issues on NixOS (nftables
  # firewall conflict + tunnel init failure under nix-ld).
  cfg = {
    host = "mobile-phx.cwie.net";
    port = 443;
    user = "rodrigob";
    workDomain = "ccbill.local";
  };
in {
  # openfortivpn needs the ppp kernel module for the tunnel interface.
  boot.kernelModules = [ "ppp_generic" "ppp_mppe" "ppp_async" ];

  environment.systemPackages = with pkgs; [
    openfortivpn
    openfortivpn-webview     # SAML SSO cookie retrieval (if needed)
    samba                    # nmblookup for NetBIOS/WINS name resolution
  ];

  # Config file for openfortivpn. Password NOT stored here — provide via:
  #   sudo openfortivpn --password-on-stdin
  # Or add `password = <your-pass>` to this file after rebuild.
  environment.etc."openfortivpn/config".text = ''
    host = ${cfg.host}
    port = ${toString cfg.port}
    username = ${cfg.user}
    # Uncomment and set if the server uses a self-signed cert:
    # insecure-ssl = yes
    #
    # Uncomment to add password (stored in /etc, not in nix store):
    # password = your-password-here
    #
    # Routes to push from server (default: all traffic):
    set-routes = 1
    #
    # Use DNS pushed by the FortiGate server (resolves corp DNS names).
    pppd-use-peerdns = 1
  '';

# Resolve Windows server names via DNS and NetBIOS/WINS.
  # Search domains from VPN server: allows `ping RMLT-OVQTOT1PB0`
  # to resolve as RMLT-OVQTOT1PB0.ccbill.local, etc.
  networking.search = [
    "malta.ccbill-hq.local"
    "ccbill-hq.local"
    "cwie.net"
    "cavecreek.net"
    "ccbill.com"
    "dev.ecsuite.com"
    "securedservers.com"
    "dev.sc.local"
    "phoenixnap.com"
    "ccbill.local"
    "dev.pncp.local"
    "pncp.local"
  ];

  # systemd-resolved for DNS from VPN tunnel.
  # After connecting, ppp0 gets DNS servers pushed by FortiGate.
  # Configure with:
  #   sudo resolvectl dns ppp0 10.20.31.50 10.20.31.55
  #   sudo resolvectl domain ppp0 ~ccbill.local ~cwie.net ~cavecreek.net ~ccbill.com
  services.resolved.enable = true;
  # Use systemd-resolved in NetworkManager too.
  networking.networkmanager.dns = "systemd-resolved";

  # SAMBA config for NetBIOS name resolution.
  # The `server string` identifies this machine on the work network.
  services.samba = {
    enable = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "book3";
        "netbios name" = "BOOK3";
        "security" = "user";
        # WINS server — uncomment if your work provides one:
        # "wins server" = "x.x.x.x";
        # Become a WINS client (query WINS for name resolution):
        "wins support" = "no";
      };
    };
  };
}
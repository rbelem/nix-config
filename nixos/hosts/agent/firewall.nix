{ ... }: {
  networking.firewall = {
    enable = true;

    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
      6443  # k3s API
    ];

    allowedUDPPorts = [
      51820 # Tailscale WireGuard
    ];

    # Allow ICMP (ping)
    allowPing = true;

    # Trust Tailscale interface — allow all traffic over VPN
    trustedInterfaces = [ "tailscale0" ];

    # k3s internal ranges
    extraCommands = ''
      # Allow pod-to-pod and service traffic
      iptables -A INPUT -s 10.42.0.0/16 -j ACCEPT
      iptables -A INPUT -s 10.43.0.0/16 -j ACCEPT
    '';
  };
}

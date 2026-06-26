{ config, pkgs, ... }: {
  networking.hostName = "book3"; # Define your hostname.

  # Enables wireless support via wpa_supplicant.
  # networking.wireless.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.wireless.iwd.enable = true;

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  # Tailscale
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # Subnet router: laptop advertises the local network so the phone can access it
    # https://wiki.nixos.org/wiki/Tailscale
    useRoutingFeatures = "both";      # subnet router + accept routes when roaming
    extraUpFlags = [
      "--advertise-routes=192.168.50.0/24"
      "--accept-dns"
      "--operator=rodrigo"       # CLI without sudo
    ];
  };
  # Force tailscaled to use nftables (avoids iptables conflicts)
  # https://wiki.nixos.org/wiki/Tailscale#Native_nftables_Support_(Modern_Setup)
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # Firewall (nftables)
  # https://wiki.nixos.org/wiki/Tailscale#Native_nftables_Support_(Modern_Setup)
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ 41641 ];
    # Subnet router — WireGuard traffic may have source IP
    # different from the incoming interface
    checkReversePath = "loose";
  };
  # Faster boot (Tailscale doesn't need to wait for network online)
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;

  # Restart NetworkManager after suspend
  systemd.services.nmcli-radio-on = {
    enable = true;
    wantedBy = [ "suspend.target" ];
    after = [ "systemd-suspend.service" ];
    script =
      ''
        ${pkgs.networkmanager}/bin/nmcli radio wifi off
        sleep 3
        ${pkgs.networkmanager}/bin/nmcli radio wifi on
      '';
    serviceConfig.Type = "oneshot";
  };
}

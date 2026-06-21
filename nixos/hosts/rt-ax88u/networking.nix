# RT-AX88U — router networking
{ config, pkgs, lib, ... }: {

  networking.hostName = "rt-ax88u";
  networking.useDHCP = false;

  # WAN port (eth0 — Broadcom BCM53134 switch port 4)
  networking.interfaces.eth0.useDHCP = lib.mkDefault true;

  # LAN ports (eth1-eth4 — Broadcom switch)
  networking.bridges."br0" = {
    interfaces = [ "eth1" "eth2" "eth3" "eth4" ];
  };

  networking.interfaces.br0 = {
    ipv4.addresses = [{
      address = "192.168.1.1";
      prefixLength = 24;
    }];
  };

  # DHCP server for LAN (dnsmasq replaces removed isc-dhcpd)
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = "br0";
      dhcp-range = [ "192.168.1.100,192.168.1.254,255.255.255.0,12h" ];
      dhcp-option = [
        "3,192.168.1.1"     # router
        "6,1.1.1.1,8.8.8.8" # DNS
      ];
    };
  };

  # NAT for LAN→WAN
  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = [ "br0" ];
  };

  # Firewall — open web UI, SSH, DHCP
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 67 68 53 ];
  };
}

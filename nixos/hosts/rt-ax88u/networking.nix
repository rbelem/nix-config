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

  # DHCP server for LAN
  services.dhcpd4 = {
    enable = true;
    interfaces = [ "br0" ];
    extraConfig = ''
      option subnet-mask 255.255.255.0;
      option broadcast-address 192.168.1.255;
      option routers 192.168.1.1;
      option domain-name-servers 1.1.1.1, 8.8.8.8;
      subnet 192.168.1.0 netmask 255.255.255.0 {
        range 192.168.1.100 192.168.1.254;
      }
    '';
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

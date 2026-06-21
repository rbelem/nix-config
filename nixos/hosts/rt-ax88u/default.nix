# ASUS RT-AX88U (BCM4908) — router NixOS config
{ pkgs, lib, inputs, ... }: {

  imports = [
    ./hardware-configuration.nix
    ./kernel.nix
    ./networking.nix
    ./merlin-web-ui.nix
  ];

  # Embedded CFE bootloader — no GRUB
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Router-optimized NixOS
  boot.tmp.cleanOnBoot = true;
  system.stateVersion = "24.11";

  nixpkgs.hostPlatform = "aarch64-linux";

  # Minimal system — no desktop, no sound, no printing
  services.openssh.enable = true;
  services.getty.autologinUser = "root";

  # Nix daemon for remote deployment
  nix.daemonCPUSchedPolicy = "idle";
  nix.settings.trusted-users = [ "root" ];

  # Log to flash (RAM buffer + periodic sync)
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=64M
    SystemMaxUse=0
  '';

  # Firmware size optimization
  documentation.enable = false;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;

  # No binaries we don't need
  environment.defaultPackages = [];
  environment.systemPackages = with pkgs; [
    vim
    curl
    kmod
    ethtool
    tcpdump
    iperf3
  ];
}

{ config, lib, ... }: {
  imports = [ ];
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.configurationLimit = 10;
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "ext4";
    neededForBoot = true;
  };
  swapDevices = [ { device = "/dev/sda2"; } ];
  networking.useDHCP = true;
  # system.stateVersion set in nixos/hosts/agent/default.nix (24.11). Don't set here —
  # duplicate at equal priority causes eval error.
}

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
  system.stateVersion = "24.05";
}

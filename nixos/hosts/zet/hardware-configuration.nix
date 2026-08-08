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
  # No swap: nixos-infect disk layout has no sda2 (sda1=root, sda15=EFI).
  # Stale swapDevices entry broke swap.target at activation (nixos-rebuild failure).
  networking.useDHCP = true;
  # system.stateVersion set in nixos/hosts/zet/default.nix (24.11). Don't set here —
  # duplicate at equal priority causes eval error.
}

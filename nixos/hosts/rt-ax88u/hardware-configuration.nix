# ASUS RT-AX88U — hardware configuration
# BCM4908 Cortex-A53 dual-core, 512MB RAM, NAND flash
{ config, lib, pkgs, modulesPath, ... }: {

  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # BSP kernel (not upstream linuxPackages)
  boot.kernelPackages = lib.mkForce pkgs.linuxPackagesFor pkgs.rt-ax88u-bsp-kernel;
  boot.kernelParams = [
    "console=ttyS0,115200"
    "earlycon"
    "root=/dev/mtdblock9"
    "rootfstype=squashfs"
    "ro"
  ];

  # Flash partition layout (Merlin CFE)
  # MTD partition layout from kernel DTS (BCM4908 reference):
  #   mtd0: boot (CFE)
  #   mtd1: env (NVRAM)
  #   mtd2: flash (device info)
  #   mtd3: firmware (kernel + rootfs)
  #   mtd4: firmware2 (fallback)
  #   mtd5: data (JFFS2 user config)
  fileSystems."/" = {
    device = "/dev/mtdblock9";
    fsType = "squashfs";
    options = [ "ro" ];
  };

  fileSystems."/data" = {
    device = "/dev/mtdblock10";
    fsType = "jffs2";
    options = [ "rw" "noatime" ];
  };

  # NVRAM device (CFE environment)
  boot.kernelModules = [ "mtd" "mtdblock" "mtdram" ];

  # Broadcom hardware watchdog
  hardware.watchdog.enable = true;
  hardware.watchdog.package = pkgs.rt-ax88u-bsp-kernel;

  nixpkgs.hostPlatform = "aarch64-linux";
}

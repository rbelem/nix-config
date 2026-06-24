# ASUS RT-AX88U — hardware configuration
# BCM4908 Cortex-A53 dual-core, 512MB RAM, 256MB NAND flash
#
# Boot flow:
#   CFE → init NAND → attach UBI → mount BcmFs-ubifs
#   → read vmlinux.lz → decompress LZMA → patch DTB → jump to kernel
#   → initramfs → mount USB root → switch_root → NixOS stage 2
#
# Reference: docs/rt-ax88u-stock-firmware-analysis.md
{ config, lib, pkgs, ... }: {

  # BSP kernel via linuxPackagesFor wrapper.
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.rt-ax88u-bsp-kernel;
  # BSP kernel uses CFE-provided DTB, not upstream device-tree infrastructure
  hardware.deviceTree.enable = false;
  boot.kernelModules = [ "mtd" "mtdblock" ];
  boot.kernelParams = [
    "console=ttyS0,115200"
    "earlycon"
    # No root= — initramfs handles root mounting (USB or NFS)
    # Kernel cmdline from stock DTB:
    "coherent_pool=4M"
    "cpuidle_sysfs_switch"
    "pci=pcie_bus_safe"
    "rootwait"
  ];

  # MTD partition layout (from kernel DTS BCM4908 reference):
  #   mtd0: boot (CFE)
  #   mtd1: env (NVRAM)
  #   mtd2: flash (device info)
  #   mtd3: firmware (kernel + rootfs)
  #   mtd4: firmware2 (fallback)
  #   mtd5: data (JFFS2 user config)

  # Root filesystem on USB SSD (via initramfs)
  # The kernel + initramfs are served from UBI NAND (loaded by CFE).
  # NixOS root is on USB; NAND flash is read-only for firmware only.
  fileSystems."/" = {
    device = "/dev/sda2";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "vfat";
    options = [ "noatime" ];
  };

  # Placeholder for Nix store on USB root (default is /nix on root device)
  # nix.settings.store = "/nix";

  nixpkgs.hostPlatform = "aarch64-linux";
}

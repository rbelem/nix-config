# BSP kernel configuration for RT-AX88U
{ pkgs, lib, ... }: {

  # Use the custom BSP kernel package
  boot.kernelPackages = lib.mkIf (pkgs ? rt-ax88u-bsp-kernel)
    (pkgs.linuxPackagesFor pkgs.rt-ax88u-bsp-kernel);

  # Kernel build ID for module directory
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "earlycon=uart8250,mmio32,0xff800600"
  ];

  # Hardware drivers built into kernel (not modules)
  boot.blacklistedKernelModules = [ ];

  # Broadcom NVRAM driver
  boot.kernelModules = [ "mtd" "mtdblock" ];

  # Firmware
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [ ];
}

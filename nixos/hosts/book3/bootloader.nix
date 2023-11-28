{ config, pkgs, ... }: {
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 1;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
    ];
    kernel.sysctl = { "vm.swappiness" = 100; };

    consoleLogLevel = 0;
    plymouth.enable = true;
    initrd = {
      verbose = false;
      # Show the plymouth login screen to unlock luks
      systemd.enable = true;
    };
  };

  zramSwap.enable = true;
}

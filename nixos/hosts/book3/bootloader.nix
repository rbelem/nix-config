{ config, pkgs, ... }: {
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 1;
    };

    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];
    kernelModules = [
      "v4l2loopback"
      "snd-aloop"
      "xe"
    ];

    extraModprobeConfig = ''
      options v4l2loopback video_nr=42 exclusive_caps=1 max_width=4096 max_height=4096 card_label="Virtual Webcam"
      options iwlwifi power_save=1
    '';

    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
      # Backlight control for Samsung Galaxy Book
      "acpi_backlight=native"
      # Intel GPU power saving
      "i915.enable_fbc=1"
      "i915.enable_psr=1"
      "i915.enable_dc=2"
      # SOF audio DSP power saving
      "snd-sof-pci.power_save=1"
      # Suspend mode: s2idle (freeze) for Samsung Galaxy Book
      # Try "mem_sleep_default=deep" if S3 is supported
      "mem_sleep_default=s2idle"
    ];
    kernel.sysctl = {
      "vm.swappiness" = 100;
      # Kernel hardening
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.tcp_syncookies" = 1;
    };

    consoleLogLevel = 0;
    plymouth.enable = true;
    initrd = {
      verbose = false;
      # Show the plymouth login screen to unlock luks
      systemd.enable = true;
    };
  };

  zramSwap.enable = true;

  # Dynamic power profiles (integrates with KDE Power Management)
  services.power-profiles-daemon.enable = true;
}

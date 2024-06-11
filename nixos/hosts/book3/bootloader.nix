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
    ];

    extraModprobeConfig = ''
      options v4l2loopback video_nr=42 exclusive_caps=1 max_width=4096 max_height=4096 card_label="Virtual Webcam"
    '';

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

# Samsung Galaxy Book3 360 | NP730QFG-KF1BR
{ pkgs, inputs, ... }: {

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-laptop-ssd


    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./bluetooth.nix
    ./bootloader.nix
    ./display.nix
    ./id.nix
    ./keyboard.nix
    ./networking.nix
    ./nvme.nix
    ./sensors.nix
    ./sound.nix
    ./touch.nix

    ../../common

    ../../users/rodrigo

    ../../desktop/fonts.nix
    ../../desktop/kde.nix
    ../../desktop/monitor-brightness.nix
    ../../desktop/virtual-webcam.nix
    ../../desktop/waydroid.nix
  ];

  boot.tmp.cleanOnBoot = true;

  # Services
  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    flatpak.enable = true;
    geoclue2.enable = true;
    printing = {
      enable = true;
      drivers = [ pkgs.epson-escpr ];
    };
    udev.packages = [
      pkgs.android-udev-rules
      pkgs.qmk-udev-rules
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}

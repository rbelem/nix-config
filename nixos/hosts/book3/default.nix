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
    ./keyboard.nix
    ./networking.nix
    ./sound.nix

    ../../common

    ../../users/rodrigo

    ../../desktop/fonts.nix
    ../../desktop/kde.nix
    ../../desktop/monitor-brightness.nix
  ];

  # Services
  services.flatpak.enable = true;
  services.geoclue2.enable = true;
  services.printing.enable = true;


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}

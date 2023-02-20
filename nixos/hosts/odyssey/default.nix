# Samsung Odyssey 2 | NP850XBC-XG1BR
{ pkgs, inputs, ... }: {

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.hardware.nixosModules.common-pc-ssd


    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./bluetooth.nix
    ./bootloader.nix
    ./display.nix
    ./keyboard.nix
    ./laptop.nix
    ./networking.nix
    ./sound.nix

    ../../common

    ../../users/rodrigo

    ../../desktop/fonts.nix
    ../../desktop/kde.nix
    ../../desktop/monitor-brightness.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

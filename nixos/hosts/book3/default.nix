# Samsung Galaxy Book3 360 | NP730QFG-KF1BR
{ pkgs, inputs, ... }: {

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel-cpu-only
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

    ../../desktop/android.nix
    ../../desktop/fonts.nix
    ../../desktop/kde.nix
    ../../desktop/monitor-brightness.nix
    ../../desktop/virtual-webcam.nix
    ../../desktop/waydroid.nix
  ];

  boot.tmp.cleanOnBoot = true;

  hardware.enableAllFirmware = true;

  # Trust the local user so nix accepts restricted settings per-build.
  # Without this, any flake using `__noChroot = true`,
  # `nixConfig.sandbox = false`, `--no-sandbox`, etc. is silently
  # rejected ("ignoring client-specified setting, you are not a trusted
  # user"). This blocks hermetic-ish builds that need network access
  # mid-build (e.g. devbox.d/bun building bun from source — rustup
  # installs the nightly toolchain, fetch-cli downloads vendor tarballs,
  # cargo pulls crates from the registry).
  #
  # Mirror the rt-ax88u host's setting (line 27 of hosts/rt-ax88u/default.nix).
  nix.settings.trusted-users = [ "root" "rodrigo" ];

  # Power management
  services.logind.settings = {
    Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  };

  # Thunderbolt device authorization daemon
  services.hardware.bolt.enable = true;

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

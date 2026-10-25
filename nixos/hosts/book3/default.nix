# Samsung Galaxy Book3 360 | NP730QFG-KF1BR
{ pkgs, inputs, ... }: {

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.hardware.nixosModules.common-pc-laptop-ssd

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./attic.nix
    ./bluetooth.nix
    ./bootloader.nix
    ./display.nix
    ./forticlient.nix
    ./id.nix
    ./keyboard.nix
    ./networking.nix
    ./nvme.nix
    ./sensors.nix
    ./shuttle-pod-tools.nix
    ./sound.nix
    ./touch.nix

    ../../common

    ../../users/rodrigo

    ../../desktop/android.nix
    ../../desktop/fonts.nix
    ../../desktop/kde.nix
    ../../desktop/monitor-brightness.nix
    #../../desktop/openlogi.nix
    ../../desktop/omarchy
    ../../desktop/virtual-webcam.nix
    ../../desktop/waydroid.nix
  ];

  # The Omarchy desktop, running on Hyprland's scrolling layout. Set this to
  # false to go back to Plasma; nixos/desktop/kde.nix follows the same switch.
  programs.omarchy.enable = true;

  # VM-only login for `nixos-rebuild build-vm`. The real machine keeps no
  # password in the repo; the VM gets a throwaway one so the Omarchy greeter
  # accepts a login. vmVariant applies only to the `build-vm` output, never
  # to `switch` or `boot`. No autologin: the point is to see the greeter.
  # mutableUsers is off and the hash is declarative, so the password is
  # enforced on every boot even when the qcow2 is reused across rebuilds
  # (initialPassword only applies when the account is created).
  virtualisation.vmVariant = {
    users.mutableUsers = false;
    users.users.rodrigo.hashedPassword = "$6$2401spiphaYxh0Ah$JquQmmlbhz7xUJyWX4o1xYhm3NBsFV6DyAD197kzqy/r6lv1G9zYMBmldMB8IvqfHBHrp29Ytri8Gprj34Bem/";

    # 3D acceleration for the VM. The default QEMU VGA has no GPU, and
    # Hyprland needs GL to start its renderer. virtio-gpu through virgl gives
    # it one. Host-only: the guest already has Mesa and hardware.graphics
    # enabled.
    virtualisation.qemu.options = [
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };

  boot.tmp.cleanOnBoot = true;

  # Cap the journal (was 1.9G unbounded on a 96G / partition).
  services.journald.settings.Journal.SystemMaxUse = "500M";

  # Cap coredump storage (262M of Aug dumps linger; vacuum only triggers at dump time).
  systemd.coredump.settings.Coredump = {
    MaxUse = "1G";
    ProcessSizeMax = "256M";
  };

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

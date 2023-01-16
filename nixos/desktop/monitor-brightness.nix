{ pkgs, lib, flake, ... }: {
  # ddcutils requires i2c
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs;
    [
      # ddcutil can manage *external* monitor's brightness
      ddcutil

      # This can control the laptop display.
      brightnessctl
    ];

  normalUsers = attrsets.filterAttrs (n: v: v.isNormalUser) users.users
  users.groups.i2c.members = attrsets.mapAttrsToList (n: v: n) normalUsers
}

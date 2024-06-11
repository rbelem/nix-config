{ config, pkgs, lib, flake, ... }: {
  # ddcutils requires i2c
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs;
    [
      # ddcutil can manage *external* monitor's brightness
      ddcutil
      ddcui

      # This can control the laptop display.
      brightnessctl
    ];

  users.groups.i2c.members = with lib; (
    let
      normalUsersObj = attrsets.filterAttrs (n: v: v.isNormalUser) config.users.users;
      normalUsersList = attrsets.mapAttrsToList (n: v: n) normalUsersObj;
    in
      normalUsersList
  );
}

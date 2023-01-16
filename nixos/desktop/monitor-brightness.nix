{ pkgs, flake, ... }: {
  # ddcutils requires i2c
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs;
    [
      # ddcutil can manage *external* monitor's brightness
      ddcutil

      # This can control the laptop display.
      brightnessctl
    ];

  users.users.${flake.config.people.myself} = {
    extraGroups = [ "i2c" ];
  };
}

{ pkgs, ... }: {
  hardware.bluetooth.enable = true;

  # Downgrade to BlueZ 5.82: 5.83+ has a regression with Soundcore Q30
  # A2DP codec negotiation ("Unable to select SEP"). Issue upstream:
  # https://github.com/bluez/bluez/issues/1330
  hardware.bluetooth.package = pkgs.bluez.overrideAttrs (old: {
    name = "bluez-5.82";
    src = pkgs.fetchurl {
      url = "mirror://kernel/linux/bluetooth/bluez-5.82.tar.xz";
      hash = "sha256-Bzn6YIqDeWfubVVytD+4mUapONHGwmEnFYqu/XQ6eQs";
    };
    patches = [];
  });

  hardware.bluetooth.settings = {
    General = {
      ControllerMode = "dual";
      JustWorksRepairing = "never";
      FastConnectable = true;
      Experimental = true;
    };
    Policy = {
      AutoEnable = true;
    };
  };
}

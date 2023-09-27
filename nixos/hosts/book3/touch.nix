{config, pkgs, ...}:
{
  environment.systemPackages = with pkgs; [
    maliit-framework
    maliit-keyboard
  ];

  # motion sensors
  hardware.sensor.iio.enable = true;

  services.xserver.wacom.enable = true;
}

{ config, ... }: {
  services.xserver.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.enable = true;

  services.xserver.screenSection = ''
    Option         "RegistryDwords"  "EnableBrightnessControl=1"
  '';
}

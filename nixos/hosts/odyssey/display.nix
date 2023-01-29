{ config, ... }: {
  # Make wayland work with nvidia
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  services.xserver.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.enable = true;

  services.xserver.screenSection = ''
    Option         "RegistryDwords"  "EnableBrightnessControl=1"
  '';
}

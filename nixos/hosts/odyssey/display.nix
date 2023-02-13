{ config, ... }: {
  boot.kernelParams = [ "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1" ];
  # Make wayland work with nvidia
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
  };

  services.xserver.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;

  services.xserver.screenSection = ''
    Option "RegistryDwords" "EnableBrightnessControl=1"
  '';
}

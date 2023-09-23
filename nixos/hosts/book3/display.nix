{ config, ... }: {
  services.xserver.enable = true;

  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
}

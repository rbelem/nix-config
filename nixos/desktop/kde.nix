{ pkgs, lib, ... }: {
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
    desktopManager.plasma5.supportDDC = true;
  };

  hardware.video.hidpi.enable = lib.mkDefault true;
  # services.xserver.dpi = 192;

  environment.systemPackages = with pkgs; [
    libsForQt5.bismuth
  ];
}

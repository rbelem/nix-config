{ pkgs, lib, ... }: {
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
    desktopManager.plasma5.supportDDC = true;
  };

  environment.systemPackages = with pkgs; [
    libsForQt5.bismuth
  ];
}

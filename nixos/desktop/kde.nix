{ pkgs, lib, ... }: {
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
    desktopManager.plasma5.supportDDC = true;
  };

  # Make GTK themes work with Wayland applications
  programs.dconf.enable = true;
}

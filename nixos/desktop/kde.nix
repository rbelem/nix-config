{ pkgs, lib, ... }: {
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
  };

  # Make GTK themes work with Wayland applications
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-kde ];
    # the setting this is all for, allows for a way to open a browser from steam-run
    xdgOpenUsePortal = true;
  };

  security.pam.services.sddm.enableKwallet = true;
  security.pam.services.kdewallet.enableKwallet = true;
}

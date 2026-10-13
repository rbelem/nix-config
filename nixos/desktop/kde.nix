{ pkgs, lib, ... }: {

  services = {
    displayManager = {
      defaultSession = "plasma";
      # Plasma Login Manager (SDDM fork with a Plasma greeter). The
      # plasmalogin PAM service substacks login, so kwallet unlock comes
      # from the plasma6 module's login.kwallet and pam_fprintd comes from
      # the fprintAuth default (pinned in hosts/book3/id.nix).
      plasma-login-manager.enable = true;
    };
    desktopManager.plasma6.enable = true;
  };

  # Make GTK themes work with Wayland applications
  programs.dconf.enable = true;
  programs.kdeconnect.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.kdePackages.xdg-desktop-portal-kde ];
    # the setting this is all for, allows for a way to open a browser from steam-run
    xdgOpenUsePortal = true;
  };

  security.pam.services.kdewallet.enableKwallet = true;
}

{ config, ... }: {
  networking.hostName = "book3"; # Define your hostname.

  # Enables wireless support via wpa_supplicant.
  # networking.wireless.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Restart NetworkManager after suspend
  systemd.services.NetworkManager = {
    wantedBy = [ "suspend.target" ];
    after = [ "suspend.target" ];
  };
}

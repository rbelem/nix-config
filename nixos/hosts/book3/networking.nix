{ config, pkgs, ... }: {
  networking.hostName = "book3"; # Define your hostname.

  # Enables wireless support via wpa_supplicant.
  # networking.wireless.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Restart NetworkManager after suspend
  systemd.services.nmcli-radio-on = {
    wantedBy = [ "suspend.target" ];
    after = [ "suspend.target" ];
    script =
      ''
        sleep 10
        ${pkgs.networkmanager}/bin/nmcli radio wifi on
      '';
    serviceConfig.Type = "oneshot";
  };

  # Restart NetworkManager after suspend
  systemd.services.nmcli-radio-off = {
    wantedBy = [ "suspend.target" ];
    before = [ "suspend.target" ];
    script = "${pkgs.networkmanager}/bin/nmcli radio wifi off";
    serviceConfig.Type = "oneshot";
  };
}

{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
    gsmartcontrol
  ];

  services.smartd.enable = true;
}

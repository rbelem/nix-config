{ pkgs, config, lib, outputs, ... }:
{
  users.users.rodrigo = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    packages = [ pkgs.home-manager ];
  };

  home-manager.users.rodrigo = import ../../home-manager/rodrigo/hosts/${config.networking.hostName}.nix;

  services.geoclue2.enable = true;
}

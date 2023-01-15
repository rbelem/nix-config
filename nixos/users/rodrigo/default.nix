{ pkgs, config, lib, outputs, ... }:
{
  users.users.rodrigo = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [
      "networkmanager"
      "wheel"
    ]

    passwordFile = config.sops.secrets.rodrigo.path;
    packages = [ pkgs.home-manager ];
  };

  sops.secrets.rodrigo = {
    sopsFile = ./rodrigo.sops.yaml;
    neededForUsers = true;
  };

  home-manager.users.rodrigo = import ../../home-manager/rodrigo/hosts/${config.networking.hostName}.nix;

  services.geoclue2.enable = true;
}

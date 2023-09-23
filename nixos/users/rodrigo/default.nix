{ pkgs, config, lib, outputs, ... }:
{
  users.users.rodrigo = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    packages = [ pkgs.devbox ];
  };
}

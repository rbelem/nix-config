{ pkgs, config, lib, outputs, ... }:
{
  users.users.rodrigo = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [
      "corectrl"
      "networkmanager"
      "video"
      "wheel"
    ];

    packages = [
      pkgs.devbox
      pkgs.ghostty
      pkgs.exfat
      pkgs.exfatprogs
      pkgs.ntfs3g
    ];
  };
}

{ pkgs, lib, ... }: {
  services.udev.packages = [
    pkgs.android-tools
  ];
}

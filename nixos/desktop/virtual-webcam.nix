{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs;
    [
      android-tools
      droidcam
      scrcpy
      usbutils
      v4l-utils
    ];
}

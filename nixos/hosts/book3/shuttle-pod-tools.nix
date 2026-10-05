# Pod-surface host tools for shuttle (rbelem/shuttle#101).
# Store payloads are squashfs images, so the pod cannot bootstrap its own
# mksquashfs/unsquashfs: these must sit on the login PATH independent of
# any devbox env. Gates the devbox-global uninstall (cutover #96).
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    squashfs-tools
    bubblewrap
    gnumake
    gcc
  ];
}

# niri with the GlobalShortcuts portal.
#
# Upstream niri does not implement org.freedesktop.impl.portal.GlobalShortcuts,
# so an application that asks the desktop for a global hotkey gets nothing on
# niri while it works on Hyprland, KDE Plasma 6 and GNOME 48. The patches in
# patches/ add the compositor side of that portal to niri.
#
# The source and the cargo lock are the ones nixpkgs pins for pkgs.niri, so
# the patches have to stay on that revision. Keeping the difference as patch
# files rather than a vendored copy of the source keeps it readable.
#
# Updating the patches:
#   1. git clone https://github.com/rbelem/niri && git checkout v26.04
#   2. cherry-pick the branch feature/global-shortcuts, or rebase it
#   3. git format-patch v26.04..HEAD -o patches/
#   4. update the list of patches below
{ niri }:

niri.overrideAttrs (old: {
  patches = [
    ./patches/0001-niri-config-add-parser-for-XDG-shortcuts-spec-triggers.patch
    ./patches/0002-niri-add-the-backend-of-the-GlobalShortcuts-portal.patch
    ./patches/0003-niri-fire-the-GlobalShortcuts-portal-shortcuts.patch
    ./patches/0004-niri-harden-the-state-of-the-GlobalShortcuts-portal.patch
  ];

  postInstall = old.postInstall + ''
    # The portal backend. xdg-desktop-portal discovers backends by scanning
    # $XDG_DATA_DIRS/xdg-desktop-portal/portals/*.portal, and the file name is
    # the backend name that portals.conf refers to.
    install -Dm0644 resources/niri.portal \
      $out/share/xdg-desktop-portal/portals/niri.portal

    # The D-Bus activation file, for the case where the portal asks for the
    # backend before the compositor has claimed the name.
    install -Dm0644 resources/org.freedesktop.impl.portal.desktop.niri.service \
      $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.niri.service
  '';
})

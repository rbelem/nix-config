{ config, ... }: {
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "br";
    # abnt2 (NOT nodeadkeys): dead-key composition is required by the
    # Ferris Sweep accent macros. nodeadkeys turns ´/`/~/^ into literals,
    # so leader+A A yields "´a" instead of "á".
    #
    # WARNING: this only sets the SYSTEM default. A Plasma session applies
    # its own copy from ~/.config/kxkbrc ([Layout] LayoutList/VariantList)
    # and silently overrides everything here. If accents break after a
    # rebuild, fix it there (or via System Settings > Keyboard > Layouts):
    #   kwriteconfig6 --file kxkbrc --group Layout --key VariantList abnt2
    #   qdbus org.kde.KWin /KWin reconfigure
    variant = "abnt2";
    options = "ctrl:nocaps,lv3:ralt_switch_multikey";
  };

  # Configure console keymap
  console.keyMap = "br-abnt2";

  hardware.keyboard.qmk.enable = true;
}

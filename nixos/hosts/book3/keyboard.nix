{ config, ... }: {
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "br";
    # abnt2 (NOT nodeadkeys): dead-key composition is required by the
    # Ferris Sweep accent macros. nodeadkeys turns ´/`/~/^ into literals,
    # so leader+A A yields "´a" instead of "á".
    variant = "abnt2";
    options = "ctrl:nocaps,lv3:ralt_switch_multikey";
  };

  # Configure console keymap
  console.keyMap = "br-abnt2";

  hardware.keyboard.qmk.enable = true;
}

{ config, ... }: {
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "br";
    variant = "nodeadkeys";
    options = "ctrl:nocaps,lv3:ralt_switch_multikey";
  };

  # Configure console keymap
  console.keyMap = "br-abnt2";

  hardware.keyboard.qmk.enable = true;
}

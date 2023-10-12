{ config, ... }: {
  # Configure keymap in X11
  services.xserver = {
    layout = "br";
    xkbVariant = "nodeadkeys";
    xkbOptions = "ctrl:nocaps,lv3:ralt_switch_multikey";
  };

  # Configure console keymap
  console.keyMap = "br-abnt2";
}

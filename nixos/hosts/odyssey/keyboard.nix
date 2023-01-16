{ config, ... }: {
  # Configure keymap in X11
  services.xserver = {
    layout = "br";
    xkbVariant = "nodeadkeys";
    xkbOptions = "ctrl:nocaps";
  };

  # Configure console keymap
  console.keyMap = "br-abnt2";
}

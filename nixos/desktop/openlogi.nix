# OpenLogi — Logitech HID++ peripherals
{ inputs, lib, ... }: {

  imports = [ inputs.openlogi.nixosModules.default ];

  # udev rules + openlogi-agent systemd user service come from the
  # upstream module. Package/launchAtLogin stay at module defaults.
  programs.openlogi.enable = true;
}

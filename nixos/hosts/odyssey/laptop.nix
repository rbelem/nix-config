{ ... }: {

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Conflicts with tlp
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;
  services.fstrim.enable = true;
}

{ config, pkgs, ... }: {

  # Run sensors-detect to get the configs to be used
  environment.systemPackages = with pkgs; [
    lm_sensors
  ];

  boot.kernelModules = [ "coretemp" ];
  services.thermald.enable = true;
  environment.etc."sysconfig/lm_sensors".text = ''
    HWMON_MODULES="coretemp"
  '';
}

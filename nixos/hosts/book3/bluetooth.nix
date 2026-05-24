{ config, ... }: {
  hardware.bluetooth.enable = true;
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
      # Some headsets (Soundcore Q30) disconnect after ~4s with "dual" mode.
      # "bredr" disables LE, which avoids the auth failure in BlueZ 5.83+.
      ControllerMode = "bredr";
      JustWorksRepairing = "never";
      FastConnectable = true;
      Experimental = true;
    };
    Policy = {
      AutoEnable = true;
    };
  };
}

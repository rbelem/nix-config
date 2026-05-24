{ inputs, outputs, ... }: {
  nix = {
    settings = {
      max-jobs = "auto";
      experimental-features = [ "nix-command" "flakes" ];
      system-features = [ "kvm" "big-parallel" ];
      auto-optimise-store = true;
      min-free = 5 * 1024 * 1024 * 1024;   # 5 GB
      max-free = 10 * 1024 * 1024 * 1024;  # 10 GB
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
    ];
    config.allowUnfree = true;
  };
}

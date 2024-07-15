{ inputs, outputs, ... }: {
  nix = {
    settings = {
      max-jobs = 1;
      experimental-features = [ "nix-command" "flakes" ];
      system-features = [ "kvm" "big-parallel" ];
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

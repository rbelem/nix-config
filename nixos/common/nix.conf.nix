{ inputs, outputs, ... }: {
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
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

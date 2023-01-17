{ config, ... }: {
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      system-features = [ "kvm" "big-parallel" ];
    };
  };

  nixpkgs.config.allowUnfree = true;
}

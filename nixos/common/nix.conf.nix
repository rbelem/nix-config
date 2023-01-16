{ config, ... }: {
  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes repl-flake
    '';
  };

  nixpkgs.config.allowUnfree = true;
}

{ inputs, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    devbox =  prev.devbox.override rec {
      buildGoModule = args: prev.buildGoModule.override { go = prev.go_1_21; } ( args // {
        version = "0.7.1";
        src = final.fetchFromGitHub {
          owner = "jetpack-io";
          repo = "devbox";
          rev = "0.7.1";
          sha256 = "sha256-xjmxikIcR3v5lpxq7w2p0bukPunUTYH/HTQhy9fAOz8=";
        };
        # To update the vendorHash
        # vendorHash = final.lib.fakeHash;
        vendorHash = "sha256-fDh+6aBrHUqioNbgufFiD5c4i8SGAYrUuFXgTVmhrRE=";
        ldflags = [
          "-s"
          "-w"
          "-X go.jetpack.io/devbox/internal/build.Version=0.7.1"
        ];
      });
    };
  };
}

{ inputs, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: rec {
    go = prev.go_1_22.overrideAttrs (finalAttrs: previousAttrs: rec {
      version = "1.22.4";

      src = final.fetchurl {
        url = "https://go.dev/dl/go${version}.src.tar.gz";
        sha256 = "sha256-/tcgZ45yinyjC6jR3tHKr+J9FgKPqwIyuLqOIgCPt4Q=";
      };

    });
    devbox =  prev.devbox.override rec {
      buildGoModule = args: prev.buildGoModule.override { go = go; } ( args // {
        version = "0.12.0-devb)";
        src = final.fetchFromGitHub {
          owner = "jetify-com";
          repo = "devbox";
          rev = "0.12.0-devb";
          # To update the sha256
          # sha256 = final.lib.fakeHash;
          sha256 = "sha256-+bnFaopmK8Yz2XSkN3wPiipoO5TsRD0IuAKUlx1KvKM=";

        };
        # To update the vendorHash
        # vendorHash = final.lib.fakeHash;
        vendorHash = "sha256-fuLKo6m/n06W4jyCc4Ki0GLlSIYZNdGFOhpasTd95x0=";

        ldflags = [
          "-s"
          "-w"
          "-X go.jetify.com/devbox/internal/build.Version=0.12.0-devb"
        ];
      });
    };
  };
}

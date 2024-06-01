{ inputs, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    devbox =  prev.devbox.override rec {
      buildGoModule = args: prev.buildGoModule.override { go = prev.go_1_22; } ( args // {
        version = "0.11.0)";
        src = final.fetchFromGitHub {
          owner = "jetify-com";
          repo = "devbox";
          rev = "0.11.0";
          # To update the sha256
          # sha256 = final.lib.fakeHash;
          sha256 = "sha256-v2EBN9zp6ssY0hWJQnhsIlRU3L7oOad46bvDUILGIv0=";

        };
        # To update the vendorHash
        # vendorHash = final.lib.fakeHash;
        vendorHash = "sha256-efXYFVs+W6jkShWrU21WCiQqfaNX/9HLD8CxesbkR0s=";

        ldflags = [
          "-s"
          "-w"
          "-X go.jetifiy.com/devbox/internal/build.Version=0.11.0"
        ];
      });
    };
  };
}

{ inputs, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    devbox =  prev.devbox.override rec {
      buildGoModule = args: prev.buildGoModule.override { go = prev.go_1_21; } ( args // {
        version = "0.9.0-pre";
        src = final.fetchFromGitHub {
          owner = "jetpack-io";
          repo = "devbox";
          rev = "0.9.0-pre";
          # To update the sha256
          # sha256 = final.lib.fakeHash;
          sha256 = "sha256-cM4PiNbfE2sEQHzklBgsJdN/iVK0nT9iZ1F/Cb5tLtM=";

        };
        # To update the vendorHash
        # vendorHash = final.lib.fakeHash;
        vendorHash = "sha256-8G1JX4vdpDAicx6A9Butl8XTjszlHMbh34pJVQyzEs4=";

        ldflags = [
          "-s"
          "-w"
          "-X go.jetpack.io/devbox/internal/build.Version=0.9.0-pre"
        ];
      });
    };
  };
}

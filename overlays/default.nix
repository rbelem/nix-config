{ inputs, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    devbox =  prev.devbox.override rec {
      buildGoModule = args: prev.buildGoModule.override { go = prev.go_1_21; } ( args // {
        version = "0.8.1";
        src = final.fetchFromGitHub {
          owner = "jetpack-io";
          repo = "devbox";
          rev = "0.8.1";
          # To update the sha256
          # sha256 = final.lib.fakeHash;
          sha256 = "sha256-Wbr0iQQgIA0dPIbonLxgVTaorZL6lLriBKEGxO5tac0=";
        };
        # To update the vendorHash
        # vendorHash = final.lib.fakeHash;
        vendorHash = "sha256-xinQHhAnx1w9R0FlcsaYgkuVBMB8bjUWNfr7t/dlv3M=";
        ldflags = [
          "-s"
          "-w"
          "-X go.jetpack.io/devbox/internal/build.Version=0.8.1"
        ];
      });
    };
  };
}

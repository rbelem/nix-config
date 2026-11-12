{ inputs, ... }:
let
  # Cross-compiled systemd v258 from nixos-25.11 (kernel 4.1 compatible).
  # systemd v260+ requires kernel >= 5.10 — BSP kernel is 4.1.51.
  # This wraps the import into a thunk (function) so it's only evaluated
  # when the overlay is actually applied (avoids evaluation on system
  # types where it's not needed, like book3's x86_64-linux).
  mkSystemdOld =
    final:
    import inputs.nixpkgs-old (
      if final.stdenv.buildPlatform.system != final.stdenv.hostPlatform.system then
        {
          # Cross-compilation (e.g. x86_64 → aarch64)
          localSystem = final.stdenv.buildPlatform.system;
          crossSystem = {
            config = final.stdenv.hostPlatform.config;
          };
        }
      else
        {
          # Native compilation
          inherit (final.stdenv.hostPlatform) system;
        }
    );
in
{
  # This one brings our custom packages from the 'pkgs' directory
  additions =
    final: _prev:
    import ../pkgs {
      pkgs = final;
      inherit inputs;
    };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # devbox 0.20.0 (nixpkgs unstable still ships 0.18.4).
    # Drop this once nixpkgs catches up.
    devbox = prev.devbox.overrideAttrs (finalAttrs: _old: {
      version = "0.20.0";
      src = final.fetchFromGitHub {
        owner = "jetify-com";
        repo = "devbox";
        tag = finalAttrs.version;
        hash = "sha256-W2PFFNdrbGVIvlRqc5uzNTlg9cgxZGBGCsPtTU3xPGs=";
      };
      vendorHash = "sha256-HSWDqEGmqZtkQHw96lYewQFDBWt7zbV3xtFXyf07llM=";
      ldflags = [
        "-s"
        "-w"
        "-X go.jetify.com/devbox/internal/build.Version=${finalAttrs.version}"
      ];
    });
  };

  # Override systemd to v258 from pinned nixpkgs-old (nixos-25.11).
  # Required because systemd v260+ (#501049) requires kernel >= 5.10,
  # but the RT-AX88U BSP kernel must stay at 4.1 to load Broadcom blobs.
  # Only apply this overlay to the rt-ax88u NixOS configuration.
  systemd-old =
    final: prev:
    let
      sd = (mkSystemdOld final).systemd;
    in
    {
      # Old systemd v258 passthru doesn't include all with* attributes that
      # the current NixOS modules (from nixos-unstable) access. Add defaults
      # for missing ones so config evaluation doesn't fail.
      systemd = sd // {
        withLogind = sd.withLogind or true;
        withNspawn = sd.withNspawn or true;
      };
    };
}

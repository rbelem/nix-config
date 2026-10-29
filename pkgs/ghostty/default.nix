# Ghostty built from an upstream release tag (override on nixpkgs)
#
# ── Updating ───────────────────────────────────────────────────────
# 1. Pick a tag from https://github.com/ghostty-org/ghostty/tags
# 2. Resolve the tag's commit SHA — annotated tags point at a tag object,
#    not at the commit, so deref it via /git/tags/<tag-sha>
# 3. Update version, rev, and hash below
# 4. Run: nix build '.#nixosConfigurations.book3.pkgs.ghostty'
#    (ghostty ships via the 'modifications' overlay, so it is not a
#    top-level flake package)
# 5. If deps changed upstream, also update rev in deps derivation
#
# Get the real hash:
#   nix-prefetch-url --unpack "https://github.com/ghostty-org/ghostty/archive/refs/tags/v<version>.tar.gz"
#   nix hash path /nix/store/<hash>-source
# ───────────────────────────────────────────────────────────────────

{ lib, fetchFromGitHub, callPackage, ghostty, zig }:

let
  # Must be valid semver — ghostty's Config.zig parses -Dversion-string
  # with std.SemanticVersion.parse().
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "ghostty-org";
    repo = "ghostty";
    rev = "83fb95624b0439ee660c2679b43b38c8b63769cd";
    hash = "sha256-ywmIjwix0P5TC8kD/zTmt82CNrLXMFETaWZj0NirpoM=";
  };
in
# Ghostty 1.4.0 declares minimum_zig_version = 0.17.0 in build.zig.zon;
# nixpkgs' ghostty pins zig_0_15 for its release build — override so this
# compiles.
(ghostty.override { zig_0_15 = zig; })
.overrideAttrs (old: {
  inherit version src;
  patches = [ ];  # nixpkgs' patches are cut against its release, not this tag

  # Use upstream's build.zig.zon.nix (Zig dep manifest) from
  # the fetched source instead of nixpkgs' deps.nix, so that
  # dependencies match the checked-out source.
  deps = callPackage "${src}/build.zig.zon.nix" {
    name = "ghostty-cache-${version}";
  };

  # 1.4.0 ships its desktop entry as dist/linux/app.desktop.in with @NAME@ /
  # @GHOSTTY@ / @APPID@ placeholders, and the build installs the target file
  # empty — which makes nixpkgs' postFixup `--replace-fail "Exec=$out/bin/ghostty"`
  # fail on it. Render the template here, pointing Exec at the store path so
  # that substitution still matches and rewrites it to a bare `ghostty`.
  postInstall = (old.postInstall or "") + ''
    install -Dm644 ${src}/dist/linux/app.desktop.in \
      $out/share/applications/com.mitchellh.ghostty.desktop
    substituteInPlace $out/share/applications/com.mitchellh.ghostty.desktop \
      --replace-fail "@NAME@" "Ghostty" \
      --replace-fail "@GHOSTTY@" "$out/bin/ghostty" \
      --replace-fail "@APPID@" "com.mitchellh.ghostty"
  '';
})

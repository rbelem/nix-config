# Ghostty built from git main (override on nixpkgs)
#
# ── Updating ───────────────────────────────────────────────────────
# 1. Visit https://github.com/ghostty-org/ghostty/commits/main
# 2. Pick the latest commit SHA and date
# 3. Update rev, versionDate, and hash below
# 4. Run: nix flake check  (or nix build '.#ghostty')
# 5. If deps changed upstream, also update rev in deps derivation
#
# Get the real hash:
#   nix-prefetch-url --unpack "https://github.com/ghostty-org/ghostty/archive/<rev>.tar.gz"
#   nix hash path /nix/store/<hash>-source
# ───────────────────────────────────────────────────────────────────

{ lib, fetchFromGitHub, callPackage, ghostty, zig }:

let
  versionDate = "2026-08-25";

  # Must be valid semver — ghostty's Config.zig parses -Dversion-string
  # with std.SemanticVersion.parse().  The pre-release suffix (after -)
  # encodes the build date so it's distinguishable from nixpkgs' release.
  version = "1.3.2-dev.${builtins.replaceStrings ["-"] [""] versionDate}";

  src = fetchFromGitHub {
    owner = "ghostty-org";
    repo = "ghostty";
    rev = "683d8db643b95cf229bfb5fe9fab9ae677920343";
    hash = "sha256-av95MqKrah0b06WhtxutbcmzqdOXORIWxvGo0rHuF7o=";
  };
in
# Ghostty main requires zig >= 0.16; nixpkgs' ghostty pins zig_0_15 for its
# release build — override so the git-main build compiles.
(ghostty.override { zig_0_15 = zig; })
.overrideAttrs (old: {
  inherit version src;
  patches = [ ];  # nixpkgs' patches don't apply to main

  # Use upstream's build.zig.zon.nix (Zig dep manifest) from
  # the fetched source instead of nixpkgs' deps.nix, so that
  # dependencies match the checked-out source.
  deps = callPackage "${src}/build.zig.zon.nix" {
    name = "ghostty-cache-${version}";
  };
})

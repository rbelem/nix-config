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

{ lib, fetchFromGitHub, callPackage, ghostty }:

let
  versionDate = "2025-06-30";

  # Must be valid semver — ghostty's Config.zig parses -Dversion-string
  # with std.SemanticVersion.parse().  The pre-release suffix (after -)
  # encodes the build date so it's distinguishable from nixpkgs' release.
  version = "1.3.2-dev.${builtins.replaceStrings ["-"] [""] versionDate}";

  src = fetchFromGitHub {
    owner = "ghostty-org";
    repo = "ghostty";
    rev = "0a5061743d608a1b0349a3305a4136ff67600921";
    hash = "sha256-PsdKDDhau2fa+Iqu07GlXmB4nDR5nZfp0hbb/a0pADc=";
  };
in
ghostty.overrideAttrs (old: {
  inherit version src;
  patches = [ ];  # nixpkgs' patches don't apply to main

  # Use upstream's build.zig.zon.nix (Zig dep manifest) from
  # the fetched source instead of nixpkgs' deps.nix, so that
  # dependencies match the checked-out source.
  deps = callPackage "${src}/build.zig.zon.nix" {
    name = "ghostty-cache-${version}";
  };
})

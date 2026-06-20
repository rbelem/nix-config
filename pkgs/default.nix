# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } } @ args:

let
  lib = pkgs.lib;

  merlin-src = args.merlin-src or (pkgs.fetchFromGitHub {
    owner = "RMerl";
    repo = "asuswrt-merlin.ng";
    rev = "e1b0940dd13456e4ac9e5fa96e4ae4154235d18c";
    sha256 = lib.fakeSha256;  # FIXME: resolve on first build
  });

  # target pkgs for aarch64: cross-compile from x86_64, native on aarch64
  crossPkgs = if pkgs.stdenv.isAarch64 then
    pkgs  # native aarch64
  else if pkgs ? pkgsCross.aarch64-multiplatform then
    pkgs.pkgsCross.aarch64-multiplatform  # cross-compile from x86_64
  else null;

in rec {
  libfprint-canvasbio-cb2000 = pkgs.callPackage ./libfprint-canvasbio-cb2000 { };

  # === RT-AX88U packages ===

  # BSP kernel — cross-compiled with Broadcom blobs
  rt-ax88u-bsp-kernel = if crossPkgs != null then
    crossPkgs.callPackage ./rt-ax88u-bsp-kernel { }
  else
    builtins.throw "aarch64 cross-compilation not available in this nixpkgs version";

  # Merlin web UI — piecemeal source build from Merlin tree
  # Each component is cross-compiled for aarch64
  merlin-web-ui = if crossPkgs != null then rec {
    www = crossPkgs.callPackage ./merlin-web-ui/www { inherit merlin-src; };
    libshared = crossPkgs.callPackage ./merlin-web-ui/libshared { inherit merlin-src; };
    libnvram = crossPkgs.callPackage ./merlin-web-ui/libnvram {
      inherit merlin-src libshared;
    };
    libpasswd = crossPkgs.callPackage ./merlin-web-ui/libpasswd { inherit merlin-src; };
    mssl = crossPkgs.callPackage ./merlin-web-ui/mssl {
      inherit merlin-src;
      openssl = crossPkgs.openssl;
    };
    libwebapi = crossPkgs.callPackage ./merlin-web-ui/libwebapi {
      inherit merlin-src;
      json-c = crossPkgs.json-c;
    };
    httpd = crossPkgs.callPackage ./merlin-web-ui/httpd {
      inherit merlin-src libshared libnvram libpasswd mssl libwebapi;
      openssl = crossPkgs.openssl;
      json-c = crossPkgs.json-c;
    };
  } else
    builtins.throw "aarch64 cross-compilation not available in this nixpkgs version";
}

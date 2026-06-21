# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { }, inputs ? { } } @ args:

let
  lib = pkgs.lib;

  # ASUS GPL source (newer than Merlin — RT-AX88U 3.0.0.4.388_24209)
  # Passed via flake input asus-gpl-rtax88u (path:/home/rodrigo/Workspace/rbelem/RT-AX88U/asuswrt)
  asus-src = args.asus-src or inputs.asus-gpl-rtax88u or
    (builtins.throw "ASUS GPL source not available. Run: nix flake lock --update-input asus-gpl-rtax88u");

  # Merlin source (kept for nvram library which Broadcom doesn't distribute in ASUS GPL)
  merlin-src = args.merlin-src or (pkgs.fetchFromGitHub {
    owner = "RMerl";
    repo = "asuswrt-merlin.ng";
    rev = "68d0ffc5fe96b7173952af80cc60e48065685873";
    sha256 = "17ac05gqkl7pmv9bm950nnwrm3gc45485n4al5klxbrsdwrmai2r";
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
    crossPkgs.callPackage ./rt-ax88u-bsp-kernel { asus-src = asus-src; }
  else
    builtins.throw "aarch64 cross-compilation not available in this nixpkgs version";

  # Merlin web UI — piecemeal source build from ASUS GPL source tree
  # Each component is cross-compiled for aarch64
  # Individual web UI packages (accessed via .merlin-web-ui.<name>)
  merlin-web-ui = if crossPkgs != null then let
    www = crossPkgs.callPackage ./merlin-web-ui/www { asus-src = asus-src; };
    libshared = crossPkgs.callPackage ./merlin-web-ui/libshared { asus-src = asus-src; };
    libnvram = crossPkgs.callPackage ./merlin-web-ui/libnvram {
      # nvram source only in Merlin GPL, not in ASUS GPL
      inherit merlin-src libshared;
    };
    libpasswd = crossPkgs.callPackage ./merlin-web-ui/libpasswd {
      asus-src = asus-src;
      libxcrypt = crossPkgs.libxcrypt;
    };
    mssl = crossPkgs.callPackage ./merlin-web-ui/mssl {
      asus-src = asus-src;
      openssl = crossPkgs.openssl;
    };
    libwebapi = crossPkgs.callPackage ./merlin-web-ui/libwebapi {
      asus-src = asus-src;
      jsonc = crossPkgs.json_c;
    };
    httpd = crossPkgs.callPackage ./merlin-web-ui/httpd {
      asus-src = asus-src;
      inherit libshared libnvram libpasswd mssl libwebapi;
      openssl = crossPkgs.openssl;
      jsonc = crossPkgs.json_c;
      libxcrypt = crossPkgs.libxcrypt;
      geoip = crossPkgs.geoip;
    };
  in crossPkgs.symlinkJoin {
    name = "merlin-web-ui";
    paths = [ www libshared libnvram libpasswd mssl libwebapi httpd ];
    meta.description = "All Merlin web UI components";
  } // { inherit www libshared libnvram libpasswd mssl libwebapi httpd; }
  else
    builtins.throw "aarch64 cross-compilation not available in this nixpkgs version";

  # Validation checks for all RT-AX88U packages
  rt-ax88u-validation = if crossPkgs != null then
    crossPkgs.callPackage ./rt-ax88u-validation {
      inherit rt-ax88u-bsp-kernel merlin-web-ui;
    }
  else
    builtins.throw "aarch64 cross-compilation not available in this nixpkgs version";

  # TRX firmware image for RT-AX88U
  # Links together kernel LZMA compression + TRX header
  rt-ax88u-firmware = if crossPkgs != null then
    pkgs.callPackage ./rt-ax88u-firmware {
      inherit rt-ax88u-bsp-kernel bcm4908lzma addtrx;
    }
  else
    builtins.throw "aarch64 cross-compilation not available in this nixpkgs version";

  # === Host tools (architecture-independent) ===

  # bcm4908lzma — LZMA wrapper for BCM4908 CFE bootloader
  bcm4908lzma = pkgs.callPackage ./bcm4908lzma { };

  # addtrx — TRX V1 header prepender
  addtrx = pkgs.callPackage ./addtrx { };
}

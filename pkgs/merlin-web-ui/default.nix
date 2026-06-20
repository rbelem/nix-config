# merlin-web-ui — ASUSWRT-Merlin web UI packages
#
# Piecemeal derivations from Merlin source tree for RT-AX88U.
# Builds library dependencies bottom-up, then httpd.
#
# Dependency chain:
#   libshared (standalone) → libnvram
#   libpasswd + mssl + libwebapi (standalone)
#   httpd (depends on all above + external OpenSSL, json-c)
#
# Exposed via pkgs/default.nix using pkgsCross.aarch64-multiplatform.

{ lib, stdenv, merlin-src, openssl, json-c, buildPackages }:

let
  toolPrefix = stdenv.cc.targetPrefix;

  # Helper: call a sub-package with the cross-compilation context
  callSubPkg = path: args:
    stdenv.mkDerivation (import path ({
      inherit lib stdenv merlin-src buildPackages;
    } // args));

in {
  www = callSubPkg ./www { };

  libshared = callSubPkg ./libshared { };

  libnvram = callSubPkg ./libnvram {
    inherit libshared;
  };

  libpasswd = callSubPkg ./libpasswd { };

  mssl = callSubPkg ./mssl {
    inherit openssl;
  };

  libwebapi = callSubPkg ./libwebapi {
    inherit json-c;
  };

  httpd = callSubPkg ./httpd {
    inherit libshared libnvram libpasswd mssl libwebapi openssl json-c;
  };
}

{ stdenv, lib, merlin-src, openssl }:

# Mini SSL wrapper — simple HTTPS abstraction used by httpd.
# Provides a thin layer over OpenSSL for HTTPS support.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  router = "${srcBase}/router";
in stdenv.mkDerivation {
  pname = "libmssl";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export CC="${stdenv.cc.targetPrefix}gcc"

    CFLAGS="-Os -Wall -fPIC"
    CFLAGS+=" -I${router}/mssl"
    CFLAGS+=" -I${openssl.dev}/include"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I${router}"

    cd ${router}/mssl
    $CC $CFLAGS -c -o mssl.o mssl.c
    ${stdenv.cc.targetPrefix}ar rcs libmssl.a mssl.o
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp libmssl.a $out/lib/
    cp mssl.h $out/include/
  '';

  meta = {
    description = "ASUSWRT-Merlin mini SSL wrapper";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

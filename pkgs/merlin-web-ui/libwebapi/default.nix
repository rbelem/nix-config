{ stdenv, lib, merlin-src, json-c }:

# Web API library — provides REST API endpoints for the web UI.
# Used by httpd to expose router configuration via HTTP.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  router = "${srcBase}/router";
in stdenv.mkDerivation {
  pname = "libwebapi";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export CC="${stdenv.cc.targetPrefix}gcc"

    CFLAGS="-Os -Wall -fPIC"
    CFLAGS+=" -I${router}/libwebapi"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I${json-c.dev}/include"
    CFLAGS+=" -I${router}"

    cd ${router}/libwebapi
    $CC $CFLAGS -c -o webapi.o webapi.c
    ${stdenv.cc.targetPrefix}ar rcs libwebapi.a webapi.o
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp libwebapi.a $out/lib/
    cp webapi.h $out/include/
  '';

  meta = {
    description = "ASUSWRT-Merlin web API library";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

{ stdenv, lib, merlin-src }:

# Password hashing library used by httpd for authentication.
# Two files: passwd.c + passwd.h — statically linked into httpd.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  router = "${srcBase}/router";
in stdenv.mkDerivation {
  pname = "libpasswd";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export AR="$CC -arch $ARCH -syslibroot /"
    export CC="${stdenv.cc.targetPrefix}gcc"
    export CROSS_COMPILE="${stdenv.cc.targetPrefix}"

    CFLAGS="-Os -Wall -fPIC"
    CFLAGS+=" -I${router}/libpasswd"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I${router}"

    cd ${router}/libpasswd
    $CC $CFLAGS -c -o passwd.o passwd.c
    ${stdenv.cc.targetPrefix}ar rcs libpasswd.a passwd.o
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp libpasswd.a $out/lib/
    cp passwd.h $out/include/
  '';

  meta = {
    description = "ASUSWRT-Merlin password hashing library";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

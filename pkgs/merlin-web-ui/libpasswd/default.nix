{ stdenv, lib, merlin-src, libxcrypt }:

# Password hashing library used by httpd for authentication.
# Two files: passwd.c + passwd.h — statically linked into httpd.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
in stdenv.mkDerivation {
  pname = "libpasswd";
  version = "merlin-ng";

  src = merlin-src;

  buildInputs = [ libxcrypt ];

  buildPhase = ''
    export CC="${stdenv.cc.targetPrefix}gcc"
    CFLAGS="-Os -Wall -fPIC -std=gnu17"

    SRC="$PWD/release/src-rt-5.02axhnd"
    CFLAGS+=" -I$SRC/router/libpasswd"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I$SRC/router"
    CFLAGS+=" -Ddbg(fmt,args...)=fprintf(stderr,fmt,##args)"

    cd "$SRC/router/libpasswd"
    $CC $CFLAGS -c -o passwd.o passwd.c
    ${stdenv.cc.targetPrefix}ar rcs libpasswd.a passwd.o
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp "$SRC/router/libpasswd/libpasswd.a" $out/lib/
    cp "$SRC/router/libpasswd/passwd.h" $out/include/
  '';

  meta = {
    description = "ASUSWRT-Merlin password hashing library";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

{ stdenv, lib, merlin-src, jsonc }:

# Web API library — provides REST API endpoints for the web UI.
# Used by httpd to expose router configuration via HTTP.

stdenv.mkDerivation {
  pname = "libwebapi";
  version = "merlin-ng";

  src = merlin-src;

  NIX_CFLAGS_COMPILE = [ "-I${jsonc.dev}/include/json-c" ];

  buildPhase = ''
    export CC="${stdenv.cc.targetPrefix}gcc"
    CFLAGS="-Os -Wall -fPIC -std=gnu17"

    SRC="$PWD/release/src-rt-5.02axhnd"
    KCFG="${merlin-src}/release/src-rt-5.02axhnd/kernel/linux-4.1/config_base.6a"

    # Generate rtconfig.h (needed by shared.h)
    echo "/* Auto-generated */" > "$SRC/router/shared/rtconfig.h"
    while IFS='=' read -r key val; do
      case "X$key" in
        XCONFIG_*) echo "#define RTCONFIG_$(echo "$key" | sed 's/^CONFIG_//') $val" ;;
      esac
    done < "$KCFG" >> "$SRC/router/shared/rtconfig.h"

    # Fix broken paren in shared.h (Broadcom typo)
    sed -i 's/__attribute__((unused) \*/__attribute__((unused)) */g' "$SRC/router/shared/shared.h"

    CFLAGS+=" -I$SRC/router/libwebapi"
    CFLAGS+=" -I${merlin-src}/release/src-rt-5.02axhnd/include"
    CFLAGS+=" -I$SRC/router"
    CFLAGS+=" -I$SRC/router/shared"
    CFLAGS+=" -I$SRC/router/httpd"
    CFLAGS+=" -I${merlin-src}/release/src-rt-5.02axhnd/bcmdrivers/broadcom/net/wl/impl51/main/src/include"

    cd "$SRC/router/libwebapi"
    $CC $CFLAGS -c -o webapi.o webapi.c
    ${stdenv.cc.targetPrefix}ar rcs libwebapi.a webapi.o
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp "$SRC/router/libwebapi/libwebapi.a" $out/lib/
    cp "$SRC/router/libwebapi/webapi.h" $out/include/
  '';

  meta = {
    description = "ASUSWRT-Merlin web API library";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

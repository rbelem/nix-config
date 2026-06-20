{ stdenv, lib, merlin-src, libshared }:

# libnvram — Broadcom NVRAM access library.
# Provides read/write access to CFE NVRAM via MTD.
# Links against libshared.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  kernelConfig = "${srcBase}/kernel/linux-4.1/config_base.6a";
  toolPrefix = stdenv.cc.targetPrefix;

in stdenv.mkDerivation {
  pname = "libnvram";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export CC="${toolPrefix}gcc"

    CFLAGS="-Os -Wall -fPIC"

    SRC="$PWD/release/src-rt-5.02axhnd"

    # Generate rtconfig.h (needed by shared.h)
    echo "--- Generating rtconfig.h ---"
    echo "/* Auto-generated */" > "$SRC/router/shared/rtconfig.h"
    while IFS='=' read -r key val; do
      case "X$key" in
        XCONFIG_*) echo "#define RTCONFIG_$(echo "$key" | sed 's/^CONFIG_//') $val" ;;
      esac
    done < "${kernelConfig}" >> "$SRC/router/shared/rtconfig.h"

    CFLAGS+=" -I$SRC/router/nvram"
    CFLAGS+=" -I$SRC/router/shared"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I${srcBase}/bcmdrivers/broadcom/net/wl/impl51/main/src/include"

    echo "=== Building libnvram ==="
    echo "CFLAGS: $CFLAGS"

    cd "$SRC/router/nvram"

    # Compile NVRAM sources
    $CC $CFLAGS -c -o nvram_linux.o nvram_linux.c
    $CC $CFLAGS -c -o nvram_convert.o nvram_convert.c

    # Create shared library (links libshared)
    $CC -shared -o libnvram.so \
      nvram_linux.o nvram_convert.o \
      -L${libshared}/lib -lshared -ldl
  '';

  installPhase = ''
    SRC="$PWD/release/src-rt-5.02axhnd"
    mkdir -p $out/lib $out/include
    cp "$SRC/router/nvram/libnvram.so" $out/lib/
    cp "$SRC/router/nvram/nvram_convert.h" $out/include/
  '';

  meta = {
    description = "Broadcom NVRAM library for ASUS RT-AX88U";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

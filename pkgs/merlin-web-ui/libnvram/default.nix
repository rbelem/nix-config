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

    CFLAGS="-Os -Wall -fPIC -std=gnu17"

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
    CFLAGS+=" -include .nvram_prefix.h"

    echo "=== Building libnvram ==="
    echo "CFLAGS: $CFLAGS"

    cd "$SRC/router/nvram"

    # Merlin's prebuilt target: copy sysdeps over originals first
    cp sysdeps/* ./ -f

    # Prepend declarations for missing Broadcom utility functions
    # (_file_lock/_file_unlock from missing utils.h)
    cat > .nvram_prefix.h << 'PRIVEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/file.h>
static inline int _file_lock(const char *dir, const char *tag) {
    char path[256];
    snprintf(path, sizeof(path), "%s/.%s.lock", dir, tag);
    int fd = open(path, O_CREAT | O_RDWR, 0644);
    if (fd < 0) return -1;
    if (flock(fd, LOCK_EX) < 0) { close(fd); return -1; }
    return fd;
}
static inline void _file_unlock(int fd) {
    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
}
PRIVEOF

    # Compile NVRAM sources (include prefix to provide missing symbols)
    $CC $CFLAGS -c -o nvram_linux.o nvram_linux.c
    $CC $CFLAGS -c -o nvram_convert.o nvram_convert.c

    # Create shared library (links libshared)
    $CC -shared -o libnvram.so \
      nvram_linux.o nvram_convert.o \
      -L${libshared}/lib -lshared -ldl
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    # Files are at SRC/router/nvram/ after buildPhase's cd
    cp "$SRC/router/nvram/libnvram.so" $out/lib/
    cp "$SRC/router/nvram/nvram_convert.h" $out/include/
  '';

  meta = {
    description = "Broadcom NVRAM library for ASUS RT-AX88U";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

{ stdenv, lib, merlin-src }:

# libshared — ASUSWRT-Merlin shared utility library.
#
# This is the core library used by all Merlin components.
# Combines source-compiled objects with prebuilt Broadcom blobs.
# Build flags match Merlin's router/shared/Makefile for HND_ROUTER_AX.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  router = "${srcBase}/router";
  hndSrc = srcBase;
  kernelConfig = "${srcBase}/kernel/linux-4.1/config_base.6a";

  # cross-compiler tool prefix
  toolPrefix = stdenv.cc.targetPrefix;

  # Compiler flags matching Merlin's shared/Makefile for HND_ROUTER_AX
  # NOTE: kernel headers intentionally omitted — they conflict with modern
  # glibc (C23 keyword clash) and aren't needed for userspace code.
  baseCFlags = [
    "-Os" "-Wall" "-fPIC"
    "-I${router}/shared"
    "-I${router}"
    "-I${hndSrc}/bcmdrivers/opensource/include/bcm963xx"
    "-I${hndSrc}/shared/opensource/include/bcm963xx"
    "-I${hndSrc}/router/nvram"
  ];

  baseDefines = [
    "-DHND_ROUTER" "-DHND_ROUTER_AX" "-DLINUX26" "-DCONFIG_BCMWL5"
    "-DWL11AC_80P80" "-DWL11AC_160"
    "-D__EXPORTED_HEADERS__" "-DTEST1" "-DTRAFFIC_MGMT"
    "-DASUS_DDNS" "-DTRANSLATE_ON_FLY" "-DFLASH_EMULATOR" "-DLinux"
    "-DCHIP_4908" "-DCONFIG_BCM94908"
    "-DLINUX_KERNEL_VERSION=264451"
    "-DDEBUG_NOISY" "-DDEBUG_RCTEST"
  ];

in stdenv.mkDerivation {
  pname = "libshared";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export CC="${toolPrefix}gcc"
    export AR="${toolPrefix}ar"
    export LD="${toolPrefix}ld"

    CFLAGS="${builtins.concatStringsSep " " (baseCFlags ++ baseDefines)}"

    echo "=== Building libshared ==="

    SRC="$PWD/release/src-rt-5.02axhnd"
    SDIR="$SRC/router/shared"

    # Generate rtconfig.h from Merlin kernel config
    echo "--- Generating rtconfig.h ---"
    echo "/* Auto-generated */" > "$SDIR/rtconfig.h"
    while IFS='=' read -r key val; do
      case "X$key" in
        XCONFIG_*) echo "#define RTCONFIG_$(echo "$key" | sed 's/^CONFIG_//') $val" ;;
      esac
    done < "${kernelConfig}" >> "$SDIR/rtconfig.h"
    cat >> "$SDIR/rtconfig.h" << 'RTEOC'
#define RTCONFIG_HND_ROUTER_AX y
#define RTCONFIG_BCMARM y
#define RTCONFIG_SHP
#define BUILD_NAME "RT-AX88U"
RTEOC

    # Objects: prebuilt blobs take priority
    SOURCE_OBJS=""
    for f in "$SDIR"/*.c; do
      base=$(basename "$f" .c)
      if [ -f "$SDIR/prebuild/RT-AX88U/$base.o" ]; then
        echo "  [prebuilt] $base.o"
        cp "$SDIR/prebuild/RT-AX88U/$base.o" "$SDIR/"
        SOURCE_OBJS="$SOURCE_OBJS $SDIR/$base.o"
      else
        echo "  [compile] $base.c"
        $CC $CFLAGS -c -o "$SDIR/$base.o" "$f" \
          && SOURCE_OBJS="$SOURCE_OBJS $SDIR/$base.o" \
          || echo "  [skip] $base.c"
      fi
    done

    # sysdeps/broadcom sources
    echo "=== sysdeps/broadcom ==="
    if [ -d "$SDIR/sysdeps/broadcom" ]; then
      for f in "$SDIR/sysdeps/broadcom"/*.c; do
        [ -f "$f" ] || continue
        base=$(basename "$f" .c)
        echo "  [compile] $f"
        $CC $CFLAGS -c -o "$SDIR/sysdeps_broadcom_$base.o" "$f" \
          && SOURCE_OBJS="$SOURCE_OBJS $SDIR/sysdeps_broadcom_$base.o" \
          || echo "  [skip] $f"
      done
    fi

    # Link shared library
    echo "=== Linking libshared.so ==="
    echo "Objects: $SOURCE_OBJS"
    $CC -shared -o "$SDIR/libshared.so" $SOURCE_OBJS -lpthread -lm
  '';

  installPhase = ''
    SRC="$PWD/release/src-rt-5.02axhnd"
    mkdir -p $out/lib $out/include
    cp "$SRC/router/shared/libshared.so" $out/lib/
    cp "$SRC/router/shared"/*.h $out/include/ 2>/dev/null || true
  '';

  meta = {
    description = "ASUSWRT-Merlin shared utility library for RT-AX88U";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

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
  sharedDir = "${router}/shared";
  prebuiltDir = "${sharedDir}/prebuild/RT-AX88U";
  kernelDir = "${srcBase}/kernel/linux-4.1";
  extraDir = "${srcBase}/../components";

  # cross-compiler tool prefix
  toolPrefix = stdenv.cc.targetPrefix;

  # Compiler flags matching Merlin's shared/Makefile for HND_ROUTER_AX
  baseCFlags = [
    "-Os" "-Wall" "-fPIC"
    "-I${sharedDir}"
    "-I${router}"
    "-I${srcBase}/include"
    "-I${kernelDir}/include"
    "-I${kernelDir}/arch/arm64/include"
    "-I${hndSrc}/bcmdrivers/opensource/include/bcm963xx"
    "-I${hndSrc}/shared/opensource/include/bcm963xx"
    "-I${hndSrc}/userspace/private/include"
    "-I${extraDir}/wlioctl/include"
    "-I${extraDir}/proto/include"
    "-I${srcBase}/shared/bcmwifi/include"
    "-I${extraDir}/math/include"
    "-I${srcBase}/wl/sys"
  ];

  # Defines from Merlin's shared Makefile + common.mak for BCM4908
  baseDefines = [
    "-DHND_ROUTER" "-DHND_ROUTER_AX" "-DLINUX26" "-DCONFIG_BCMWL5"
    "-DWL11AC_80P80" "-DWL11AC_160"
    "-D__EXPORTED_HEADERS__" "-DTEST1" "-DTRAFFIC_MGMT"
    "-DASUS_DDNS" "-DTRANSLATE_ON_FLY" "-DFLASH_EMULATOR" "-DLinux"
    "-DCHIP_4908" "-DCONFIG_BCM94908"
    "-DLINUX_KERNEL_VERSION=264451"  # 4.1.51 = 4*65536 + 1*256 + 51
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
    echo "CFLAGS: $CFLAGS"

    cd "${sharedDir}"

    # Objects compiled from source (all .c files with no prebuilt override)
    SOURCE_OBJS=""
    for f in *.c; do
      base=$(basename "$f" .c)
      # Skip files that have prebuilt versions
      if [ -f "${prebuiltDir}/$base.o" ]; then
        echo "  [prebuilt] $base.o (from Merlin prebuild)"
        cp "${prebuiltDir}/$base.o" .
      else
        echo "  [compile] $base.c"
        $CC $CFLAGS -c -o "$base.o" "$f"
      fi
      SOURCE_OBJS="$SOURCE_OBJS $base.o"
    done

    # Compile sysdeps/broadcom sources
    echo "=== sysdeps/broadcom ==="
    for f in sysdeps/broadcom/*.c; do
      base=$(basename "$f" .c)
      echo "  [compile] $f"
      $CC $CFLAGS -c -o "sysdeps_broadcom_$base.o" "$f"
      SOURCE_OBJS="$SOURCE_OBJS sysdeps_broadcom_$base.o"
    done

    # Link shared library
    echo "=== Linking libshared.so ==="
    $CC -shared -o libshared.so $SOURCE_OBJS -lpthread -lm
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp "${sharedDir}/libshared.so" $out/lib/
    cp "${sharedDir}"/*.h $out/include/ 2>/dev/null || true
  '';

  meta = {
    description = "ASUSWRT-Merlin shared utility library for RT-AX88U";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

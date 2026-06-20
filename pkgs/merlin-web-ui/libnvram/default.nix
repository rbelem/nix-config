{ stdenv, lib, merlin-src, libshared }:

# libnvram — Broadcom NVRAM access library.
#
# Provides read/write access to the CFE NVRAM variables stored in
# a dedicated flash partition. Uses the kernel MTD device (/dev/mtdblockX)
# via ioctl calls to the Broadcom NVRAM driver.
# Links against libshared for utility functions.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  router = "${srcBase}/router";
  nvramDir = "${router}/nvram";
  kernelDir = "${srcBase}/kernel/linux-4.1";

  toolPrefix = stdenv.cc.targetPrefix;

in stdenv.mkDerivation {
  pname = "libnvram";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export CC="${toolPrefix}gcc"

    CFLAGS="-Os -Wall -fPIC"
    CFLAGS+=" -I${nvramDir}"
    CFLAGS+=" -I${router}/shared"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I${kernelDir}/include"
    CFLAGS+=" -I${kernelDir}/arch/arm64/include"

    echo "=== Building libnvram ==="

    cd "${nvramDir}"

    # Compile NVRAM sources
    $CC $CFLAGS -c -o nvram_linux.o nvram_linux.c
    $CC $CFLAGS -c -o nvram_convert.o nvram_convert.c

    # Create shared library (links libshared)
    $CC -shared -o libnvram.so \
      nvram_linux.o nvram_convert.o \
      -L${libshared}/lib -lshared -ldl
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp "${nvramDir}/libnvram.so" $out/lib/
    cp "${nvramDir}/nvram_convert.h" $out/include/
  '';

  meta = {
    description = "Broadcom NVRAM library for ASUS RT-AX88U";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

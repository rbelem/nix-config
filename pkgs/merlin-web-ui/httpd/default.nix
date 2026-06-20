{ lib, stdenv, merlin-src, libshared, libnvram, libpasswd, mssl, libwebapi, openssl, json-c }:

# httpd — ASUSWRT-Merlin web server and UI backend.
#
# This is the main web server binary that serves the router's admin UI.
# It compiles Merlin source files from router/httpd/ and links against
# libshared, libnvram, and other Merlin libraries plus OpenSSL and json-c.
#
# For Broadcom-proprietary components without source (pwenc, web_hook,
# web-broadcom), we use prebuilt .o files from Merlin's prebuild directory
# when available, or create stubs when not.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  router = "${srcBase}/router";
  httpdDir = "${router}/httpd";
  kernelDir = "${srcBase}/kernel/linux-4.1";
  prebuiltDir = "${httpdDir}/prebuild/RT-AX88U";

  toolPrefix = stdenv.cc.targetPrefix;

in stdenv.mkDerivation {
  pname = "merlin-httpd";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export CC="${toolPrefix}gcc"
    export AR="${toolPrefix}ar"
    export LD="${toolPrefix}ld"

    # === Compiler flags matching Merlin's httpd/Makefile for HND_ROUTER_AX ===
    CFLAGS="-Os -Wall -fPIC"
    CFLAGS+=" -I${httpdDir}"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I${router}"
    CFLAGS+=" -I${router}/shared"
    CFLAGS+=" -I${kernelDir}/include"
    CFLAGS+=" -I${kernelDir}/arch/arm64/include"
    CFLAGS+=" -I${srcBase}/../components/wlioctl/include"
    CFLAGS+=" -I${srcBase}/../components/proto/include"

    # Merlin defines
    CFLAGS+=" -DHND_ROUTER -DHND_ROUTER_AX"
    CFLAGS+=" -DASUS_DDNS -DTRANSLATE_ON_FLY -DFLASH_EMULATOR -DLinux -DWSC"
    CFLAGS+=" -DWL11AC_80P80 -DWL11AC_160"
    CFLAGS+=" -DCHIP_4908 -DCONFIG_BCM94908"
    CFLAGS+=" -DLINUX_KERNEL_VERSION=264451"
    CFLAGS+=" -D_FILE_OFFSET_BITS=64"

    # External library includes
    CFLAGS+=" -I${openssl.dev}/include"
    CFLAGS+=" -I${json-c.dev}/include/json-c"
    CFLAGS+=" -I${router}/mssl"
    CFLAGS+=" -I${router}/libpasswd"
    CFLAGS+=" -I${router}/libwebapi"

    echo "=== Building httpd ==="
    echo "CC: $CC"
    cd "${httpdDir}"

    # === Compile source objects ===
    echo "Compiling source files..."
    for src in \
      httpd.c cgi.c ej.c web.c common.c nvram_f.c \
      aspbw.c initial_web_hook.c apps.c \
      sysinfo.c data_arrays.c \
      sysdeps/web-broadcom-am.c; do
      base=$(basename "$src" .c)
      echo "  CC $src"
      $CC $CFLAGS -c -o "$base.o" "$src"
    done

    # === Copy prebuilt objects ===
    echo "Copying prebuilt objects..."
    if [ -d "${prebuiltDir}" ]; then
      cp "${prebuiltDir}/pwenc.o" .
      cp "${prebuiltDir}/web_hook.o" .
    fi

    # === Handle web-broadcom.o ===
    # For RT-AX88U, web-broadcom-am.c (compiled above) provides the
    # Broadcom-specific display functions. The generic web-broadcom.o
    # is not available for this model. If needed at link time,
    # we create a stub.
    if [ ! -f "web-broadcom.o" ] && [ ! -f "${prebuiltDir}/web-broadcom.o" ]; then
      echo "  [stub] web-broadcom.o (not available for RT-AX88U)"
      cat > web-broadcom_stub.c << 'STUB'
/* Stub for web-broadcom.o — RT-AX88U uses web-broadcom-am.o instead */
int web_broadcom_init(void) { return 0; }
STUB
      $CC $CFLAGS -c -o web-broadcom.o web-broadcom_stub.c
    fi

    # === Link httpd binary ===
    echo "Linking httpd..."
    $CC -o httpd \
      httpd.o cgi.o ej.o web.o common.o nvram_f.o \
      aspbw.o initial_web_hook.o apps.o \
      sysinfo.o data_arrays.o web-broadcom-am.o \
      pwenc.o web_hook.o web-broadcom.o \
      -L${libshared}/lib -lshared \
      -L${libnvram}/lib -lnvram \
      -L${libpasswd}/lib -lpasswd \
      -L${mssl}/lib -lmssl \
      -L${libwebapi}/lib -lwebapi \
      -L${openssl.out}/lib -lssl -lcrypto -ldl \
      -L${json-c}/lib -ljson-c \
      -lm -lpthread -lgcc_s
  '';

  installPhase = ''
    mkdir -p $out/sbin
    cp "${httpdDir}/httpd" $out/sbin/
    ${toolPrefix}strip $out/sbin/httpd || true
  '';

  meta = {
    description = "ASUSWRT-Merlin web server for RT-AX88U";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

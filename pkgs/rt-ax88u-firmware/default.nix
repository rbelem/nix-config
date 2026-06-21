{ lib, stdenv, rt-ax88u-bsp-kernel, bcm4908lzma, addtrx, python3 }:

# rt-ax88u-firmware — Bootable TRX firmware image for ASUS RT-AX88U.
#
# CFE bootloader on BCM4908 expects a TRX V1 image with LZMA-compressed
# kernel. The pipeline is:
#   1. Take the kernel Image (ARM64 boot executable)
#   2. LZMA-compress with bcm4908lzma (lc1, lp2, pb2, d22)
#   3. Prepend TRX V1 header with CRC32
#
# The resulting .trx file can be flashed via CFE's web interface or
# TFTP recovery, or written directly to the firmware MTD partition.

stdenv.mkDerivation {
  pname = "rt-ax88u-firmware";
  version = "merlin-ng";

  src = null;
  phases = [ "buildPhase" "installPhase" ];
  preferLocalBuild = true;

  nativeBuildInputs = [ bcm4908lzma addtrx python3 ];

  buildPhase = ''
    runHook preBuild

    echo "=== Building RT-AX88U firmware image ==="
    KERNEL="${rt-ax88u-bsp-kernel}/Image"

    if [ ! -f "$KERNEL" ]; then
      echo "FAIL: kernel Image not found at $KERNEL"
      exit 1
    fi

    echo "1. Copying kernel Image ($(stat -c%s "$KERNEL") bytes)..."
    cp "$KERNEL" kernel.Image

    echo "2. LZMA compressing with bcm4908lzma..."
    bcm4908lzma kernel.Image kernel.lzma

    echo "3. Adding TRX V1 header..."
    addtrx kernel.lzma firmware.trx

    echo "4. Verifying TRX image..."
    file firmware.trx
    ls -lh firmware.trx

    runHook postBuild
  '';

  installPhase = ''
    mkdir -p $out
    cp firmware.trx $out/
    ln -s firmware.trx $out/rt-ax88u-merlin-ng.trx

    # Also keep the compressed kernel standalone
    cp kernel.lzma $out/
  '';

  meta = {
    description = "Bootable TRX firmware image for ASUS RT-AX88U";
    longDescription = ''
      TRX V1 firmware image containing LZMA-compressed BSP kernel.
      Can be flashed via CFE web interface or written to the firmware
      MTD partition (mtd3/mtd4) on the RT-AX88U.
    '';
    homepage = "https://github.com/RMerl/asuswrt-merlin.ng";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.all;  # build tool, output is arch-agnostic
  };
}

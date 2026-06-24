{ lib, stdenv, rt-ax88u-bsp-kernel, bcm4908lzma, mtdutils, python3 }:

# rt-ax88u-firmware-ubi — UBI firmware image for ASUS RT-AX88U.
#
# CFE bootloader on BCM4908 expects firmware in UBI .w format:
#   UBI → UBIFS volume "BcmFs-ubifs" → vmlinux.lz (LZMA kernel)
#
# Pipeline:
#   1. LZMA-compress kernel Image → vmlinux.lz  (bcm4908lzma)
#   2. Create UBIFS image with vmlinux.lz       (mkfs.ubifs)
#   3. Wrap in UBI image                         (ubinize)
#
# NAND parameters (from stock firmware analysis):
#   Page size:  2048 bytes  (ubinize -m 2048)
#   PEB size:   128 KB      (ubinize -p 131072)
#   Sub-page:   2048        (ubinize -s 2048)
#   LEB size:   126976      (131072 - 2 × 2048)
#   Max LEBs:   576         (72 MB UBI area / 128 KB)
#   Volume:     BcmFs-ubifs (CFE mount target)
#
# Reference: docs/rt-ax88u-stock-firmware-analysis.md

let
  # NAND geometry constants matching RT-AX88U's Macronix/Spansion NAND
  pageSize = 2048;      # NAND page size (bytes)
  pebSize = 131072;     # physical erase block (128 KB)
  subPageSize = 2048;   # sub-page = page for modern NAND
  lebSize = pebSize - 2 * pageSize;  # 126976 (EC + VID headers occupy full pages)
  maxLebs = 576;        # 72 MB UBI area / 128 KB PEBs
  volName = "BcmFs-ubifs";

in stdenv.mkDerivation {
  pname = "rt-ax88u-firmware-ubi";
  version = "merlin-ng";

  src = null;
  phases = [ "buildPhase" "installPhase" ];
  preferLocalBuild = true;

  nativeBuildInputs = [ bcm4908lzma mtdutils python3 ];

  buildPhase = ''
    runHook preBuild

    KERNEL="${rt-ax88u-bsp-kernel}/Image"
    echo "=== Building RT-AX88U UBI firmware ==="

    # ── Step 1: LZMA-compress kernel ──────────────────────────
    echo "1. Compressing kernel Image → vmlinux.lz"
    if [ ! -f "$KERNEL" ]; then
      echo "FAIL: kernel Image not found at $KERNEL"
      exit 1
    fi
    KERNEL_SIZE=$(stat -c%s "$KERNEL")
    echo "   Kernel Image: $KERNEL_SIZE bytes"
    bcm4908lzma "$KERNEL" vmlinux.lz
    LZMA_SIZE=$(stat -c%s vmlinux.lz)
    echo "   vmlinux.lz: $LZMA_SIZE bytes ($(echo "scale=1; 100*$LZMA_SIZE/$KERNEL_SIZE" | bc)%)"

    # ── Step 2: Create UBIFS with vmlinux.lz ──────────────────
    echo "2. Creating UBIFS image (mkfs.ubifs)"
    mkdir -p rootfs
    cp vmlinux.lz rootfs/

    mkfs.ubifs \
      -F                          `# free-space fixup (for raw NAND write)` \
      -m ${builtins.toString pageSize}  `# minimum I/O = page size` \
      -e ${builtins.toString lebSize}   `# LEB size` \
      -c ${builtins.toString maxLebs}   `# max LEB count` \
      -x lzo                      `# LZO compression` \
      -r rootfs                   `# root directory` \
      -o rootfs.ubifs

    UBIFS_SIZE=$(stat -c%s rootfs.ubifs)
    echo "   rootfs.ubifs: $UBIFS_SIZE bytes"

    # ── Step 3: Wrap in UBI image ─────────────────────────────
    echo "3. Creating UBI image (ubinize)"
    cat > ubi.ini << UBICFG
    [${volName}]
    mode=ubi
    image=rootfs.ubifs
    vol_id=0
    vol_type=dynamic
    vol_name=${volName}
    vol_flags=autoresize
    UBICFG

    ubinize \
      -v \
      -o ubi.img \
      -m ${builtins.toString pageSize}    `# min I/O` \
      -p ${builtins.toString pebSize}     `# PEB size` \
      -s ${builtins.toString subPageSize} `# sub-page size` \
      ubi.ini

    UBI_SIZE=$(stat -c%s ubi.img)
    echo "   ubi.img: $UBI_SIZE bytes"

    # ── Summary ────────────────────────────────────────────────
    echo "=== UBI firmware build complete ==="
    echo "  vmlinux.lz:    $LZMA_SIZE bytes"
    echo "  rootfs.ubifs:  $UBIFS_SIZE bytes"
    echo "  ubi.img:       $UBI_SIZE bytes"

    runHook postBuild
  '';

  installPhase = ''
    mkdir -p $out
    cp vmlinux.lz   $out/
    cp rootfs.ubifs $out/
    cp ubi.img      $out/
    ln -s ubi.img   $out/rt-ax88u-merlin-ng.ubi
  '';

  meta = {
    description = "UBI firmware image for ASUS RT-AX88U (BCM4908)";
    longDescription = ''
      UBI firmware image in the format expected by the CFE bootloader.
      Contains an UBIFS volume "BcmFs-ubifs" with the LZMA-compressed
      BSP kernel as vmlinux.lz.

      Flash via CFE recovery mode (TFTP) or write directly to the
      firmware MTD partition (mtd3). For web UI upload, this must be
      wrapped with a CFE image header (vtoken) — see stock firmware
      .w format.

      Does NOT include vmlinux.sig (kernel signature). Secure boot
      investigation is tracked separately (P0.2).
    '';
    homepage = "https://github.com/RMerl/asuswrt-merlin.ng";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.all;
  };
}
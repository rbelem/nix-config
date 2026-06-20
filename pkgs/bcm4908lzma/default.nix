{ lib, lzma, writeShellScriptBin }:

# bcm4908lzma — LZMA compression wrapper for BCM4908 CFE boot images
#
# The CFE bootloader on BCM4908/BCM49408 based routers (ASUS RT-AX88U,
# GT-AC5300) expects kernel images compressed with specific LZMA parameters.
# This is a thin wrapper around lzma with the correct flags.
#
# Reference: OpenWrt target/linux/bcm4908/image/Makefile
#   define Build/bcm4908lzma
#     $(STAGING_DIR_HOST)/bin/lzma e -lc1 -lp2 -pb2 -d22 $@ $@.new
#     mv $@.new $@
#   endef

writeShellScriptBin "bcm4908lzma" ''
  set -euo pipefail
  INPUT=''${1:?Usage: bcm4908lzma <input> [output]}
  OUTPUT=''${2:-"$INPUT.lzma"}
  ${lib.getExe lzma} e -lc1 -lp2 -pb2 -d22 "$INPUT" "$OUTPUT"
  echo "bcm4908lzma: $INPUT -> $OUTPUT ($(stat -c%s "$OUTPUT") bytes)"
''

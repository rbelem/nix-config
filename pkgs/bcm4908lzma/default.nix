{ lib, python3, writeShellScriptBin }:

# bcm4908lzma — LZMA compression wrapper for BCM4908 CFE boot images
#
# The CFE bootloader on BCM4908/BCM49408 based routers (ASUS RT-AX88U,
# GT-AC5300) expects kernel images compressed with specific LZMA parameters
# using the LZMA Alone format (not .xz):
#   - lc=1 (literal context bits)
#   - lp=2 (literal position bits)
#   - pb=2 (position bits)
#   - dict=22 (dictionary size 2^22 = 4MB)
#
# Uses Python's lzma module since the standalone lzma command from
# xz-utils doesn't support the LZMA Alone format with custom filters.

writeShellScriptBin "bcm4908lzma" ''
  set -euo pipefail
  INPUT=''${1:?Usage: bcm4908lzma <input> [output]}
  OUTPUT=''${2:-"$INPUT.lzma"}

  ${python3}/bin/python3 -c "
import lzma, sys

with open('$INPUT', 'rb') as f:
    data = f.read()

# LZMA Alone format with CFE-compatible parameters
filters = [{
    'id': lzma.FILTER_LZMA1,
    'dict_size': 1 << 22,       # d22 = 4MB
    'lc': 1,                    # lc1
    'lp': 2,                    # lp2
    'pb': 2,                    # pb2
}]
compressed = lzma.compress(data, format=lzma.FORMAT_ALONE, filters=filters)

with open('$OUTPUT', 'wb') as f:
    f.write(compressed)

orig = len(data)
comp = len(compressed)
ratio = 100.0 * comp / orig if orig else 0
print(f'bcm4908lzma: $INPUT -> $OUTPUT')
print(f'  original: {orig} bytes')
print(f'  compressed: {comp} bytes')
print(f'  ratio: {ratio:.1f}%')
"
''

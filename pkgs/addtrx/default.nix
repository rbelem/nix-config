{ lib, python3, writeShellScriptBin }:

# addtrx — Prepend a TRX V1 header to a firmware image.
#
# CFE bootloaders on Broadcom BCM4908 routers (ASUS RT-AX88U) expect
# firmware images in TRX format:
#
#   [28-byte TRX header] [Image 0...] [Image 1...] [Image 2...]
#
# TRX V1 header layout (trxhdr.h):
#   uint32 magic         = 0x30524448 ("HDR0")
#   uint32 len           = total file length
#   uint32 crc32         = CRC32 of flag_version..end
#   uint32 flag_version  = 0 (flags:15, version:16)
#   uint32 offsets[3]    = offsets to images (0 = none)

writeShellScriptBin "addtrx" ''
  set -euo pipefail
  INPUT=''${1:?Usage: addtrx <input> [output]}
  OUTPUT=''${2:-"$INPUT.trx"}

  ${python3}/bin/python3 -c "
import struct, sys, zlib

with open('$INPUT', 'rb') as f:
    data = f.read()

magic = 0x30524448  # 'HDR0'
flag_version = 0
total_len = 28 + len(data)

crc_data = struct.pack('<I', flag_version) + data
crc32_val = zlib.crc32(crc_data) & 0xFFFFFFFF

header = struct.pack('<IIIIIII', magic, total_len, crc32_val, flag_version, 28, 0, 0)

with open('$OUTPUT', 'wb') as f:
    f.write(header)
    f.write(data)

print(f'addtrx: $INPUT -> $OUTPUT')
print(f'  header: 28 bytes')
print(f'  data:   {len(data)} bytes')
print(f'  total:  {total_len} bytes')
print(f'  CRC32:  0x{crc32_val:08x}')
"
''

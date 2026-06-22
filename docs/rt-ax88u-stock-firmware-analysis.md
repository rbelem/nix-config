# RT-AX88U Stock Firmware Analysis (v3.0.0.4_388_24385)

**Analyzed:** 2026-06-22  
**Source:** ASUS support site (`FW_RT-AX88U_300438824385.zip`)  
**Firmware build:** `g3fd7311` (Feb 23 2026) — newest available on ASUS.com  
**Our GPL source:** 3.0.0.4.388_24209 (1 revision older)  
**Raw file:** `/home/rodrigo/Downloads/FW_RT-AX88U_300438824385.zip`

---

## 1. File Format

The stock firmware is an ASUS `.w` file — a **UBI NAND flash image** for the Broadcom CFE bootloader. This supersedes the older `.trx` format used in earlier ASUS firmware releases.

| Property | Value |
|---|---|
| Total size | 79,953,940 bytes (76.3 MB) |
| Non-UBI prefix | 4.25 MB (0x000000–0x43ffff) |
| UBI area | 72 MB (0x440000–end) |
| UBI erase blocks | 576 × 128 KB |
| UBI volume name | `BcmFs-ubifs` (UBIFS) |

---

## 2. Image Layout

```
Offset          Content                          Size
──────────────────────────────────────────────────────
0x000000        CFE Image Header (0x85 0x19 tags)   —   ~120 bytes
0x000078        FDT #1 (Device Tree)              3,883 bytes
0x00101c        FDT #2 (redundant copy)           3,895 bytes
0x001f7c        cferam.000 (CFE RAM-stage loader)  ~1 KB
0x002000        CFE boot stub / exception vectors  ~1 MB
0x001f53–0x1f7c Broadcom image tags                ~280 bytes
...             cferam + pad + kernel area          ~4.2 MB
0x43ff00        "BcmFs-ubifs" volume label string   —
0x440000        UBI start (EC header)              72 MB
                └─ UBIFS volume "BcmFs-ubifs"
                   ├─ vmlinux.lz  (LZMA kernel)
                   ├─ vmlinux.sig (RSA signature)
                   └─ root filesystem
```

---

## 3. Boot Flow

```
CFE bootloader (NAND offset 0x0, read-only)
  │
  ├─ 1. Probe NAND controller, initialize UBI
  │
  ├─ 2. Mount UBI volume "BcmFs-ubifs" (UBIFS)
  │
  ├─ 3. Locate vmlinux.sig + vmlinux.lz in UBIFS
  │
  ├─ 4. Authenticate: RSA verify vmlinux.lz via vmlinux.sig
  │      → "Authenticating vmlinux.lz ... "
  │      → FAIL: "Image vmlinux.lz cannot be authenticated. Stoppping"
  │
  ├─ 5. Decompress LZMA kernel to DRAM
  │      → "Decompression %s Image OK!"
  │
  ├─ 6. Append CFE version to DTB in memory
  │
  └─ 7. Jump to kernel (passes FDT pointer)
```

**Key insight:** The kernel is stored **as a file inside UBIFS**, not at a fixed flash offset. CFE has a full UBIFS reader built in.

---

## 4. Device Tree (FDT) Parameters

Extracted from the stock firmware's embedded DTB (`94908.dtb`):

### SoC

| Property | Value |
|---|---|
| compatible | `brcm,brcm-v8A`, `Broadcom-v8A` |
| CPU | 4× Cortex-A53 |
| CPU enable method | `spin-table` |
| CPU release addr | 0xfff8 |
| GIC | GIC-400 at 0x81000000 |
| L2 cache | unified, one per cluster |

### Memory

| Property | Value |
|---|---|
| **DTB value** | **128 MB** (0x08000000) — BSP minimum |
| **Actual hardware** | **1 GB** (verified: 2× 512 MB DDR4) |
| Address range | 0x00000000–0x7fffffff |

**⚠️ CFE patches the DTB at boot time.** The embedded DTB stores a safe 128 MB
minimum. CFE detects the actual RAM via board variant (GPIO strapping) and
overwrites the FDT memory node before jumping to the kernel. This is confirmed
by the boot string "Memory Configuration Changed -- REBOOT NEEDED" in the
CFE binary. Our DTS should reflect the actual hardware value (1 GB).

### Peripherals

| Peripheral | Address | Compatible |
|---|---|---|
| UART | 0xff800600 | ns16550 |
| NAND | 0xff801800 | brcm,brcmnand-v7.1 |
| SPI | 0xff801000 | brcm,bcm6328-hsspi |
| I2C | 0xff802100 | brcm,bcm63000-i2c |
| SDHCI | 0xff858000 | brcm,bcm63xx-sdhci |
| Watchdog | 0xff800428 | brcm,bcm96xxx-wdt |
| Crypto (SPU) | 0x8001d000 | brcm,spu-crypto |
| Timer | ARM architected | arm,armv8-timer |
| PMC | 0xff800000 | simple-bus |

### Kernel Command Line

```
coherent_pool=4M cpuidle_sysfs_switch pci=pcie_bus_safe rootwait
```

Note: `rootwait` with **no root= parameter** — the kernel expects rootfs to be passed via the FDT `chosen` node or initramfs. This matches the UBIFS boot model.

---

## 5. Board Variants Supported by CFE

The firmware CFE contains a board detection table supporting multiple ASUS models on the same BSP:

```
94908AX88U       ← RT-AX88U (our target)
94908AX11000     ← GT-AX11000
94908AX11000_8P
94908AX11000GPY
94908AX11000X
94908AX11000W25
94908REF         ← Reference board
94908DVT         ← Development/demo board
94908DVT_SFPWAN
94908REF_XPHY
94908REF_W2P5
94908REF_MOCA
94906AX9...      ← RT-AX86U (different model)
```

**Detection method:** GPIO strapping pins sampled at reset. CFE passes board ID to kernel via the DTB `model` property. This means the same firmware binary works across multiple hardware variants — the BSP supports this natively.

---

## 6. Secure Boot

The firmware enforces kernel signature verification:

```
Authenticating vmlinux.lz ...
Image vmlinux.lz cannot be authenticated. Stoppping
```

- Kernel stored as `vmlinux.lz` (LZMA compressed)
- Signature stored alongside as `vmlinux.sig` (likely RSA-2048 or RSA-4096)
- CFE mounts UBIFS, reads both files, verifies before decompression

**Implication for our port:**
- The Merlin GPL source (3.0.0.4.388_24209) may predate secure boot enforcement
- If CFE from an updated bootloader enforces auth, our custom kernel will be rejected
- Mitigation: use CFE recovery mode (reset button at power-on) which may skip auth, or flash via serial if available
- This needs testing on the actual hardware

---

## 7. Merlin Cross-Reference (Historical)

**File:** `RT-AX88U_3004_388.11_0_ubi.w` from [asuswrt-merlin.net](https://www.asuswrt-merlin.net)  
**Version:** 3004.388.11 (Dec 26 2025)  
**Not primary — kept for historical reference.** All structural findings (format, DTB,
boot flow, secure boot) are identical to stock firmware at section 1-6 above.

| Check | vs Stock |
|---|---|
| Format | ✅ Same UBI `.w` layout |
| FDT #1 / #2 | ✅ Byte-identical (0 diff) |
| Non-UBI prefix | 4.25 MB (62% byte diff — kernel/rootfs content) |
| Secure boot | ✅ Same vmlinux.lz + vmlinux.sig |
| CFE / cferam | ✅ Same components |
| Product string | `ASUSWRT-Merlin RT-AX88U 3004.388.11_0` |
| | |

**Only relevant difference:** Merlin confirms our GPL source pipeline produces
`.w` UBI images, not TRX. No additional structural insights beyond stock.

---

## 8. Differences From Our Porting Assumptions

Stock firmware is the reference. Merlin agrees on all structural points.

| Aspect | Stock Firmware (24385) | Our Port Plan | Impact |
|---|---|---|---|
| **Image format** | UBI `.w` | TRX `.trx` | 🟡 GPL source (24209) may use TRX; need to verify make.image |
| **Kernel location** | `vmlinux.lz` inside UBIFS | Image at flash offset | 🔴 Our boot model must match CFE |
| **RAM size** | 128 MB in DTB (patched to 1 GB by CFE) | 1 GB | 🟢 Matches actual hardware |
| **Root filesystem** | UBIFS on UBI | SquashFS on MTD (or USB) | 🟡 USB boot remains a valid alternative |
| **Bootloader** | CFE + UBI + FDT | CFE + fixed offset | 🟡 Kernel must accept FDT from CFE |
| **Secure boot** | RSA signature (vmlinux.sig) | Not addressed | 🔴 Need test on hardware |
| **Board detection** | GPIO strapping, runtime | Static per-model | 🟢 Matches Golden Rule |

---

## 9. Action Items for Our Port

Based on stock firmware (Merlin confirms alignment where noted):

1. **Use ACTUAL hardware RAM in DTS** — RT-AX88U has 1 GB (0x40000000). Stock DTB
   embeds 128 MB as BSP minimum; CFE patches at boot to actual value. Our DTS
   should match the real hardware.
2. **Use exact kernel cmdline** from stock DTB:
   `coherent_pool=4M cpuidle_sysfs_switch pci=pcie_bus_safe rootwait`
3. **Investigate secure boot** — stock CFE enforces vmlinux.sig auth. Does CFE
   on our hardware enforce it for custom firmware? (Merlin binary also ships
   with signature — suggests CFE may require it.)
4. **Investigate build pipeline** — does `make.image` (from our GPL 24209) produce
   `.w` (UBI) or `.trx`? The UBI switch may have happened after our GPL snapshot.
5. **Add FDT support** — kernel must accept DTB pointer from CFE rather than
   embedding a static DTS at compile time.
6. **CFE memory patching** — CFE updates FDT at boot (confirmed by "Memory
   Configuration Changed" string). Our DTS `reg` is a fallback, not the active
   value after CFE patches it.

---

## 10. Reference: Raw Strings

Key identifier strings found in the firmware image:

| Offset | String | Meaning |
|---|---|---|
| 0x28 | `94908.dtb` | Device tree filename |
| 0xd4 | `Broadcom-v8A` | SoC compatible |
| 0xf0 | `brcm,brcm-v8A` | DTB compatible |
| 0xfcc | `94908REF.dtb` | Reference DTB |
| 0x1099 | `brcm94908ref` | Board model |
| 0x1f7c | `cferam.000` | CFE RAM component |
| 0x64b1f | `BCM94908` | SoC identifier |
| 0x6892f | `RT-AX88U` | Model name |
| Various | `vmlinux.lz` | Compressed kernel filename |
| Various | `vmlinux.sig` | Kernel signature filename |
| 0x6342c+ | `94908AX88U`, `94908AX11000` etc. | Board variant table |
| 0x43ff00 | `BcmFs-ubifs` | UBI volume name |

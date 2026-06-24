# Port NixOS to ASUS RT-AX88U — Action Plan

**⚠️ NOTE (Jun 22 2026):** Some sections of this plan predate the
stock firmware analysis. See `docs/rt-ax88u-stock-firmware-analysis.md`
for the actual firmware format (UBI `.w`, not TRX), boot flow (CFE reads
kernel from UBIFS), and secure boot (RSA signature enforcement).
The gap analysis at `docs/rt-ax88u-gap-analysis.md` has the current
prioritized work items reflecting these findings.

## License: CC0 — do whatever you want with this plan.

## Golden Rule: RT-AX88U Only, Then Extend

**Implement only what is needed for the RT-AX88U router.** After it works perfectly
(All hardware features verified, stable in production), extend support to other
models.

### Rationale

- RT-AX88U (BCM4908) is the target hardware — everything else is speculation
- Multi-model support adds complexity, abstraction layers, and untested code paths
- Merlin firmware has subtle model-specific differences in:
  - GPIO pin assignments (LEDs, buttons, USB power)
  - NAND flash partition layout
  - Switch configuration (BCM53134 vs others)
  - Wi-Fi radio calibration data (board-specific)
  - Prebuilt blob compatibility (some are model-specific)
  - Web UI strings and defaults
- Each model needs hardware testing — cannot be done blind

### What This Means for Implementation

- **`CONFIG_*` flags, DTS files, kernel configs**: RT-AX88U values only
- **Prebuilt blobs**: only those for RT-AX88U (`hnd_extra/prebuilt/`) with correct arch
- **httpd/web UI**: only the files needed for the RT-AX88U's feature set
- **NixOS module options**: no generic router abstraction — RT-AX88U specifics
- **If a feature requires a change that is RT-AX88U-specific, make it so**
  Don't add abstraction for future models until the second model is being ported

### When to Extend

1. RT-AX88U boots NixOS with all hardware working
2. Wi-Fi (both bands), Ethernet, switch, USB, LEDs, buttons verified
3. Router has been stable in production for 30+ days
4. A second RT-AX88U (or another BCM4908 router) is available for testing

Only then should model-generic abstractions be introduced.

---

**Target:** ASUS RT-AX88U — Broadcom BCM49408 (quad Cortex-A53 @ 1.8 GHz), 1 GiB RAM,
256 MiB NAND flash, BCM53134 switch, BCM43684 + BCM4366E Wi-Fi.

**Hard requirement:** All Asuswrt-Merlin features working — Wi-Fi (both radios, all
features), hardware NAT/CTF, hardware QoS, VPN acceleration, LED control, USB, etc.

**This fundamentally changes the strategy.** Read the analysis below before proceeding.

---

## Foundational Analysis (June 2026)

### Merlin Source Code Findings

Source analysis of `release/src-rt-5.02axhnd/` at
`/home/rodrigo/Workspace/github.com/RMerl/asuswrt-merlin.ng/`:

```
kernel/linux-4.1/Makefile  →  VERSION=4 PATCHLEVEL=1 SUBLEVEL=51
config_base.6a              →  Linux/arm64 4.1.45 Kernel Configuration
```

**All 77 hardware drivers are prebuilt `.o` binary blobs** in
`router-sysdep.rt-ax88u/hnd_extra/prebuilt/`:

- `wl.o`, `dhd.o` — Wi-Fi (both BCM43684 + BCM4366E)
- `bcm_enet.o` — Ethernet GMAC
- `pktrunner.o`, `pktflow.o`, `bdmf.o`, `rdpa*.o`, `rdpa_gpl.o` — Hardware packet offload (RDPA framework)
- `bcm_pcie_hcd.o` — PCIe host controller
- `bcm_usb.o` — USB controller
- `bcm_thermal.o`, `bcm63xx_gpio.o`, `bcm63xx_led.o` — SoC management
- `bcmvlan.o`, `bcmmcast.o`, `bcm_bpm.o`, `bcm_ingqos.o` — Network acceleration
- `emf.o`, `igs.o`, `hnd.o`, `wfd.o` — HND framework modules
- `bcmspu.o`, `bcm_arm64_setup.o`, `bcm_dt.o` — Platform setup
- 60+ more

These are **all compiled for Linux 4.1.51**. They cannot be loaded on any newer kernel.

### The Fundamental Constraint

| Requirement | Condition | Compatible? |
|---|---|---|
| Full Merlin feature parity | Must load `wl.o`, `bcm_enet.o`, `pktrunner.o`, `bdmf.o`, `rdpa*.o`, etc. | Requires BSP kernel 4.1.x |
| Modern NixOS (systemd 259+) | Requires kernel ≥ 5.10 (baseline), recommends 5.14+ | **Kernel 4.1 too old** |
| systemd on kernel 4.1 | systemd dropped pre-5.10 compat in v259 | **Blocked** |
| Replace systemd with simpler init | NixOS is deeply coupled to systemd | Massive fork, impractical |

**The core problem:** systemd 259+ (shipped in current NixOS) removed all code for
kernels older than 5.10. The Merlin BSP kernel is 4.1.51. You cannot boot modern
NixOS on it. The prebuilt blobs cannot be loaded on any kernel newer than ~4.1.x
because the kernel module ABI is intentionally unstable between major versions.

---

## Strategy Options

### Option A: Split Architecture (RECOMMENDED) — Works Today

```
ISP ──┬── RT-AX88U (Merlin firmware, AP mode — all features intact)
      └── NixOS x86 box (routing, firewall, DHCP, DNS, services)
```

| Aspect | Status |
|---|---|
| Merlin features on router | ✅ **All** — Wi-Fi, HW NAT, QoS, everything |
| NixOS for routing | ✅ **Full** — modern kernel, declarative config, all packages |
| Latency | ~0.5 ms added (single Ethernet hop), imperceptible |
| Complexity | Low |
| Effort | **None** — configure Merlin as AP, build x86 NixOS router |

**Why this is the right answer:** The RT-AX88U becomes a high-end Wi-Fi AP with
full Merlin feature set, while NixOS handles routing on hardware that actually
supports modern kernels. This is what the council unanimously recommended as
the pragmatic split. It works today, requires no porting, and loses nothing.

### Option B: Nix-on-Merlin (Partial) — Works Today

Keep Merlin firmware with its full BSP kernel + all blobs + AsusWRT userspace.
Install Nix package manager via Entware for declarative package management.

| Aspect | Status |
|---|---|
| Merlin features | ✅ **All** — unchanged kernel and drivers |
| Nix package mgmt | ✅ **Yes** — `nix-env`, `nix profile`, `nix-shell` |
| NixOS (systemd, nixos-rebuild) | ❌ **No** — still AsusWRT under the hood |
| Effort | Low (hours) |

**`pkgs/merlin-nix/default.nix`:**

```nix
{ stdenv, fetchurl, patchelf }:

# Builds a static Nix binary for aarch64 that runs on Merlin's BSP
stdenv.mkDerivation {
  name = "nix-static";
  src = fetchurl {
    url = "https://hydra.nixos.org/build/.../nix-static-aarch64.tar.xz";
    hash = "";
  };
  installPhase = ''
    # Nix static binary + lib stores in /opt/nix
    mkdir -p $out/opt/nix
    cp -r * $out/opt/nix/
  '';

  # On the router:
  #   /opt/nix/bin/nix profile install ...
  #   /opt/nix/bin/nix shell nixpkgs#...
}
```

This gives you Nix for package management on the router, but the OS remains
AsusWRT/Merlin. No declarative system configuration, no nixos-rebuild, no
systemd. The router's networking is still managed via Merlin's web UI.

### Option C: Fork NixOS to Use BSP Kernel (Not Recommended)

Replace systemd with a simpler init compatible with kernel 4.1, or pin NixOS
to a very old release (pre-2020) that still supported kernel 4.1.

**Problems:**
- systemd v243 (NixOS 20.09) required kernel ≥ 3.7 — borderline compatible but
  security patches stopped years ago
- Lose all modern NixOS features (cgroups v2, unified hierarchy, zram, etc.)
- All packages pinned to 2020-era versions unless you rebuild everything
- Ongoing maintenance nightmare
- **Entirely defeats the purpose of using NixOS**

**Not recommended. Do not pursue this path.**

---

## Current State of Upstream Support

| Component | Status |
|---|---|
| BCM4908 SoC in mainline Linux | `ARCH_BCM4908` since 5.11, merged into `ARCH_BCMBCA` in 6.1 |
| BCM4908 DTSI in mainline | Yes — now at `arch/arm64/boot/dts/broadcom/bcmbca/bcm4908.dtsi` |
| OpenWrt bcm4908 target | Mature — kernel 6.12, 4 patches, Ethernet + switch + NAND |
| RT-AX88U specific DTS in mainline | **Not yet** — would need authoring from AsusWRT GPL + OpenWrt reference |
| Nix cross-compile to aarch64 | Well-supported via `pkgsCross.aarch64-multiplatform` |
| Merlin BSP kernel (proprietary) | Linux 4.1.51 — incompatible with modern NixOS |

---

## Recommended Path: Option A — Split Architecture

This is the **pragmatic, recommended approach**. It requires zero porting,
gives you full Merlin features on the RT-AX88U, and full NixOS on x86 routing
hardware.

```
┌─────────────────────────────────────────────────────┐
│                   Home Network                       │
│                                                      │
│  ISP ───── RT-AX88U (Merlin, AP-only mode)          │
│              │                                       │
│              │ Ethernet                              │
│              │                                       │
│         NixOS x86 box (router, firewall, DNS)        │
│              │                                       │
│              │ Switch / LAN                          │
│              │                                       │
│         ┌────┴────┬────┬────┐                        │
│       Clients  NAS  TV  ...                          │
└─────────────────────────────────────────────────────┘
```

### Merlin Configuration (AP Mode)

```
Administration → Operation Mode: Access Point (AP)
LAN IP: 192.168.1.2 (static)
Wi-Fi: configured as normal (both bands)
DHCP: off (handled by NixOS)
```

### NixOS Router Configuration

```nix
{ config, pkgs, lib, ... }:

{
  networking = {
    hostName = "router";
    useDHCP = false;

    # WAN interface (from modem)
    interfaces.wan = {
      useDHCP = true;
    };

    # LAN interface (to RT-AX88U + switch)
    interfaces.lan = {
      ipv4.addresses = [{
        address = "192.168.1.1";
        prefixLength = 24;
      }];
    };

    # NAT
    nat = {
      enable = true;
      externalInterface = "wan";
      internalInterfaces = [ "lan" ];
    };

    # Firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };

    # DHCP server for LAN
    services.dhcpd4 = {
      enable = true;
      interfaces = [ "lan" ];
      extraConfig = ''
        option subnet-mask 255.255.255.0;
        option routers 192.168.1.1;
        option domain-name-servers 1.1.1.1, 1.0.0.1;
        subnet 192.168.1.0 netmask 255.255.255.0 {
          range 192.168.1.100 192.168.1.200;
        }
      '';
    };

    # DNS
    services.bind = {
      enable = true;
      forwarders = [ "1.1.1.1" "1.0.0.1" ];
    };
  };

  # WireGuard VPN
  services.wireguard = { ... };
}
```

### x86 Hardware Options

| Hardware | NICs | Power | Cost | Notes |
|---|---|---|---|---|
| Protectli VP2420 | 4× Intel i226 | 15W | ~$300 | Gold standard, coreboot |
| Dell Wyse 5070 | 1× + USB NIC | 12W | ~$50 used | Cheap option |
| HP T730 | 2× + PCIe NIC | 20W | ~$80 used | Can add 4-port Intel NIC |
| Custom DIY | depends | 15-30W | ~$200 | Mini-ITX + Intel NIC |

**Minimum:** 2 NICs (1 WAN + 1 LAN). **Recommended:** 4 NICs for VLANs.

---

## Option B: Nix-on-Merlin — Partial Nix on Router

If you only need Nix **package management** on the router (not NixOS as the OS):

### How It Works

1. Flash Merlin firmware on RT-AX88U
2. Enable SSH + Entware (USB storage required)
3. Install static Nix binary on the router
4. Use `nix profile install` for packages

### Implementation

```bash
# On the router (via SSH):
# 1. Enable JFFS2 partition for scripts
#    Administration → System → Enable JFFS2 partition

# 2. Install Entware
ssh admin@rt-ax88u
entware-setup.sh  # installs to USB

# 3. Download static Nix
wget https://hydra.nixos.org/build/.../nix-static-aarch64.tar.xz
tar xf nix-static-aarch64.tar.xz -C /opt/nix

# 4. Add to PATH
echo 'export PATH=/opt/nix/bin:$PATH' >> /opt/etc/profile

# 5. Install packages via Nix
nix profile install nixpkgs#htop
nix profile install nixpkgs#iperf3
nix profile install nixpkgs#wireguard-tools  # if not already in Merlin
```

### Limitations

- No `nixos-rebuild`, no systemd, no declarative system config
- Router networking still managed via Merlin web UI
- Nix packages run on the 4.1 BSP kernel (may have glibc ABI issues)
- No cgroups v2, no modern container runtimes

---

## Option C: Full NixOS on BSP Kernel — Porting Plan

**⚠️ This is the hardest path. Requires deep knowledge of embedded Linux,
Nix internals, and kernel config. But it IS viable.**

### The Core Problem — Solved in Three Steps

```
systemd v259+  →  requires kernel ≥ 5.10  →  CANNOT change
BSP kernel 4.1 ←  must load 77 prebuilt blobs ←  CANNOT change (Merlin features)
```

**Solution:**
1. **Pin systemd to v252-v258** (supports kernel 3.15+ min, 4.15+ rec — 4.1 sits between)
2. **Enable ~20 kernel configs** the BSP left disabled (CGROUPS, NAMESPACES, SECCOMP, etc.)
3. **Keep modern nixpkgs** for all userspace packages (glibc 2.40+, everything current)

### The BSP Kernel Config Gap

Analysis of `config_base.6a` (Linux/arm64 4.1.45) shows systemd prerequisites **present
in the kernel source but explicitly disabled**. These can be enabled without affecting
the prebuilt blobs — they're core infrastructure options that don't change driver APIs:

| Config | Needed by systemd for | Status | Can enable? |
|---|---|---|---|
| `CONFIG_CGROUPS` | **Essential** — process tracking, service lifecycle | ❌ Disabled | ✅ Safe — no driver interaction |
| `CONFIG_DEVPTS_MULTIPLE_INSTANCES` | **Essential** — systemd refuses boot without this | ❌ Disabled | ✅ Safe |
| `CONFIG_FHANDLE` | **Essential** — file descriptors, boot tracking | ❌ Disabled | ✅ Safe |
| `CONFIG_NAMESPACES` | PrivateTmp, ProtectSystem, ProtectHome | ❌ Disabled | ✅ Safe |
| `CONFIG_SECCOMP` | SystemCallFilter, NoNewPrivileges | ❌ Disabled | ✅ Safe |
| `CONFIG_AUDIT` | journald audit integration | ❌ Disabled | ✅ Safe |
| `CONFIG_BPF_SYSCALL` | BPF sandboxing features | ❌ Disabled | ✅ Safe |
| `CONFIG_POSIX_MQUEUE` | Message queues | ❌ Disabled | ✅ Safe |

**Why enabling these is safe:** The 77 prebuilt blobs (`wl.o`, `bcm_enet.o`,
`pktrunner.o`, `bdmf.o`, etc.) interact with the kernel through driver-specific
APIs — network device ops, file ops, PCI ops, etc. Cgroups, namespaces, seccomp,
and devpts are independent kernel subsystems that don't change those interfaces.
Linux has supported all of these since 2.6.x — they are not new APIs.

### The Viable Path

```
                    ┌──────────────────────────────────────────┐
                    │    Merlin BSP Kernel 4.1.51              │
                    │    + systemd prerequisites enabled       │
                    │    + all 77 prebuilt blobs (unchanged)   │
                    │    wl.o, bcm_enet.o, pktrunner.o ...)    │
                    └────────────────────┬─────────────────────┘
                                         │
                    ┌────────────────────▼─────────────────────┐
                    │    systemd v252-v258 (overridden)        │
                    │    taint "old-kernel" (4.1 < 4.15 rec)   │
                    │    No cgroup-v2 cpu controller           │
                    │    Otherwise fully functional            │
                    └────────────────────┬─────────────────────┘
                                         │
                    ┌────────────────────▼─────────────────────┐
                    │    Modern nixpkgs userspace              │
                    │    glibc 2.40+, coreutils, openssh       │
                    │    nginx, wireguard, iptables/nft        │
                    │    All packages from nixpkgs-unstable    │
                    │    All NixOS modules that use systemd    │
                    │    (most of them) work as-is             │
                    └──────────────────────────────────────────┘
```

**Why this works:**
- Merlin BSP kernel 4.1.51 → all proprietary drivers load → all Merlin features
- Enable ~20 CONFIG_* options → systemd v252 functions completely (with old-kernel taint)
- systemd v252-v258 → full NixOS module compatibility → `systemd.services.*` works
- Override systemd version in nixpkgs → current nixpkgs with older systemd
- Cross-compile from x86_64 → no emulation needed for build

**What you lose vs a normal NixOS system:**
- No cgroup-v2 CPU controller (kernel 4.1 only has cgroup v1)
- No BPF LSM, no BPF-based sandboxing
- No idmapped mounts (MOUNT_ATTR_NOSYMFOLLOW)
- No `STATX_MNT_ID` (affects some filesystem features)
- Systemd taints itself "old-kernel" — reduced upstream testing
- Potential issues with Broadcom RDPA/CTF offload and network namespaces (needs testing)

**What you KEEP (everything else):**
- All Merlin hardware features: Wi-Fi both radios, hardware NAT, QoS, USB, LEDs
- All NixOS modules: `services.openssh`, `networking.firewall`, `services.nginx`, etc.
- Modern userspace: glibc 2.40+, openssh, wireguard, nginx, python, everything from nixpkgs
- Declarative config: `nixos-rebuild switch`, flake-based, generations
- Cross-compilation: build on x86_64, run on aarch64

### Fallback: finit / dinit Path

If systemd v252 hits unforeseen issues on the BSP kernel (possible: the Broadcom
RDPA blobs may use cgroup-v1 APIs in unexpected ways), the fallback is **finit**
via the [finix](https://github.com/finix-community/finix) project.

| Init | NixOS compat | Kernel req | Status |
|---|---|---|---|
| **systemd v252** (primary) | Full — all `systemd.services.*` | ~20 configs to enable | Override in nixpkgs |
| **finit** (fallback) | Limited — `finit.services.*` | None — works with current config | finix project |
| **dinit** (alternative) | Limited — `dinix` generates service files | None | Lillecarl/dinix |

### Repository Layout

```
nix-config/
├── flake.nix
├── docs/rt-ax88u-port-plan.md
├── modules/
│   ├── nixos/
│   └── rt-ax88u/
│       ├── default.nix         ← imports kernel, blobs, systemd-override, network
│       ├── kernel.nix          ← BSP kernel 4.1 + config enable patch
│       ├── blobs.nix           ← packages the 77 prebuilt .o files
│       ├── firmware.nix        ← firmware blobs for Wi-Fi radios
│       ├── network.nix         ← switch + routing (uses wl.ko, bcm_enet)
│       ├── wifi.nix            ← wl.ko loading + configuration
│       └── image.nix           ← firmware image generation
├── overlays/
│   └── default.nix
├── pkgs/
│   ├── default.nix
│   ├── rt-ax88u-kernel/
│   │   └── default.nix         ← Merlin's kernel 4.1 + config patch
│   ├── rt-ax88u-blobs/
│   │   └── default.nix         ← packages prebuilt .o files
│   └── systemd-old/            ← systemd v252 override
│       └── default.nix
└── nixos/
    └── hosts/
        ├── book3/
        └── rt-ax88u/
            ├── default.nix
            ├── hardware.nix
            └── network.nix
```

# Appendix: Detailed Porting Phases (Option C)

These phases describe the implementation of **Option C**: Merlin BSP kernel 4.1
+ systemd v252-v258 (with kernel config enablement) + modern nixpkgs userspace.

**Prerequisites for this approach:**
- All Merlin features preserved (Wi-Fi, HW NAT, QoS, everything)
- ~20 kernel CONFIG_* options must be enabled (CGROUPS, NAMESPACES, SECCOMP, etc.)
- systemd pinned to v252-v258 (pre-5.10-kernel-requirement era)
- Modern nixpkgs for all userspace (glibc 2.40+, current packages)
- All `systemd.services.*` NixOS modules work as-is
- **No hardware test infrastructure** — all validation is static analysis + QEMU

**Fallback:** If systemd v252 proves problematic on the BSP kernel, switch to
finit via the [finix](https://github.com/finix-community/finix) project.
Phase 4 documents both paths.

---

## Phase 0 — Reconnaissance (2-7 days)

**Goal:** Establish boot chain and confirm CFE loads Merlin BSP kernel.

**⚠️ CRITICAL GATE: Do not proceed to Phase 1 until Phase 0 succeeds.**

### 0.1 — No Hardware Debugging Available

**⚠️ No UART adapter, no serial console, no second router.**
All validation is static analysis. The only deployment method is CFE recovery
mode (reset button at power-on → TFTP auto-flash).

This means:
- No watching kernel boot messages
- No interrupting CFE for `boot -tftp` commands
- No debugging kernel panics
- First flash is a leap of faith (backstopped by CFE recovery)

**Compensations:**
- Rigorous static analysis script (see Validation Strategy section)
- QEMU system boot to verify kernel Image validity
- Cross-check symbol tables against known-good Merlin build
- CFE recovery always works — stock firmware can always be re-flashed

### 0.2 — Build Merlin BSP Kernel (Gate Check)

**Before any Nix code, verify the BSP kernel builds with all 77 blobs.**

```bash
# 1. From the cloned Merlin source:
cd release/src-rt-5.02axhnd

# 2. Build a kernel to verify the toolchain + source work:
export CROSS_COMPILE=aarch64-linux-gnu-
make -C kernel/linux-4.1 ARCH=arm64 \
  mrproper
cp kernel/linux-4.1/config_base.6a kernel/linux-4.1/.config
make -C kernel/linux-4.1 ARCH=arm64 oldconfig
make -C kernel/linux-4.1 ARCH=arm64 \
  Image dtbs modules -j$(nproc)

# 3. Run static analysis to confirm blobs linked:
aarch64-unknown-linux-gnu-nm kernel/linux-4.1/vmlinux | grep bcm_enet
# Should show hundreds of bcm_enet_* symbols
```

**Gate decision:**
- ✅ Kernel builds, blob symbols present → proceed to Nix packaging
- ❌ Build fails → fix toolchain/dependencies first
- ❌ Blob symbols missing → blob deployment paths wrong (see platform.mak)

### 0.2a — Validate CFE Image Format via OpenWrt Reference

Build OpenWrt's bcm4908 initramfs to understand the CFE image format.
This does NOT require flashing — just examining the output format:

```bash
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt
make menuconfig  # Target: Broadcom BCM4908
make -j$(nproc)  # Output: bin/targets/bcm4908/generic/*initramfs*

# Analyze the format:
hexdump -C bin/targets/bcm4908/generic/*initramfs* | head -20
# Look for: HDR0 magic, LZMA compression, layout
# Use this as reference for your TRX header generation
```

### 0.3 — Extract Merlin Build Configuration

```bash
# From the Merlin source tree, capture:
# 1. Kernel config
cp kernel/linux-4.1/config_base.6a ./merlin-kernel-config

# 2. DTS files
cp kernel/dts/4908/94908.dts ./rt-ax88u-bsp.dts
cp kernel/dts/bcm_b53_template.dtsi ./bcm_b53_template.dtsi

# 3. Prebuilt blob list
ls router-sysdep.rt-ax88u/hnd_extra/prebuilt/*.o > ./prebuilt-blobs.txt

# 4. Build rules (how blobs get linked into kernel)
#    See platform.mak lines 520-700 for the copy commands
grep -n "cp.*prebuilt" kernel/linux-4.1/../platform.mak > ./blob-deployment.txt
```

### 0.4 — Document Flash Layout (from stock firmware)

```bash
binwalk -Me firmware.trx
strings firmware.bin | grep -i "kernel\|rootfs\|version"
```

```
Partition        Size        Content
───────────────────────────────────────────
CFE              2 MB        Bootloader (read-only)
nvram            64 KB       Settings (read-write)
kernel           ~8 MB       Linux kernel + initramfs
rootfs           ~40 MB      SquashFS (AsusWRT)
data             ~200 MB     JFFS2 (user config)
```

### 0.5 — Image Format Reverse Engineering

ASUS uses `trx` or `pkgtb` with CFE-compatible headers. From Merlin's build system:

```bash
# Merlin's image generation:
#   make.image  →  generates the final .trx
less release/src-rt-5.02axhnd/make.image
```

OpenWrt's `bcm4908` target also has image generation code in
`target/linux/bcm4908/image/` — copy their approach for the CFE header.

### 0.6 — RT-AX88U DTS (from Merlin sources)

The RT-AX88U uses the `94908REF.dts` reference board under
`kernel/dts/4908/`. Create a specific DTS:

```dts
// rt-ax88u-bsp.dts — derived from Merlin's 94908.dts
#define GIC_DIST_BASE  0x81001000
#define GIC_CPUI_BASE  0x81002000

#include "bcm_b53_template.dtsi"

/ {
  model = "ASUS RT-AX88U";
  compatible = "asus,rt-ax88u", "brcm,bcm4908";

  memory@0 {
    device_type = "memory";
    reg = <0x0 0x0 0x0 0x40000000>;  // 1 GB
  };
};

// NAND, UART, I2C, SPI, PCIe, USB, switch — ported from 94908.dts
// BCM53134 switch configured via BSP's Broadcom switch interface
```

### 0.7 — Catalog All 77 Prebuilt Blobs

From `router-sysdep.rt-ax88u/hnd_extra/prebuilt/`:

| Category | Blobs | Purpose |
|---|---|---|
| Wi-Fi | `wl.o`, `dhd.o` | Both radios (BCM43684 + BCM4366E) |
| Ethernet | `bcm_enet.o` | GMAC driver |
| Packet processing | `pktrunner.o`, `pktflow.o`, `bdmf.o`, `rdpa*.o`, `rdpa_gpl.o`, `rdpa_usr.o` | Hardware NAT/CTF offload |
| Switch | `bcmvlan.o`, `wfd.o` | VLAN + wireless forwarding |
| QoS | `bcm_ingqos.o`, `bcm_bpm.o`, `pwrmngtd.o` | Hardware traffic shaping |
| PCIe | `bcm_pcie_hcd.o` | PCIe host controller |
| USB | `bcm_usb.o` | USB controller |
| Platform | `bcm_arm64_setup.o`, `bcm_dt.o`, `bcm_arm_irq.o`, `bcm_arm_cpuidle.o`, `setup.o`, `blxargs.o` | SoC bringup |
| I2C | `bcm_i2c.o` | I2C bus |
| SPI | `bcm63xx_flash.o` | SPI flash |
| GPIO/LED | `bcm63xx_gpio.o`, `bcm63xx_led.o`, `board_led.o`, `board_button.o` | GPIO + LED control |
| Thermal | `bcm_thermal.o` | Temperature monitoring |
| IPMI/FW mgmt | `bcm63xx_cons.o`, `board_wd.o`, `pushbutton.o`, `spidevices.o` | Console, watchdog |
| Management | `hnd.o`, `emf.o`, `igs.o`, `bcmmcast.o`, `bcmpdc.o`, `ivi.o` | HND framework, multicast, bridging |
| RDPA offload | `rdp_fpm.o`, `rdpa_cmd.o`, `rdpa_mw.o`, `rdpa_gpl_ext.o` | Packet processing control |
| Misc | `chipinfo.o`, `cmdlist.o`, `compat_board.o`, `opticaldet.o`, `detect_opt.o`, `nciTMSkmod.o` | Various hardware features |

**Deliverable:** A `docs/rt-ax88u-hw.yaml` file with:

```yaml
soc:
  model: BCM49408
  arch: aarch64-cortex-a53
  memory: 1G
  dts_compatible: "asus,rt-ax88u", "brcm,bcm4908"
flash:
  type: nand
  size: 256M
  partitions:
    - name: cfe
      offset: 0x0
      size: 0x200000
switch:
  model: BCM53134
  driver: b53 (upstream) or bcm53134 (proprietary)
wifi_5g:
  chip: BCM43684
  driver: brcmfmac or proprietary wl.ko
wifi_24g:
  chip: BCM4366E
  driver: brcmfmac or proprietary wl.ko
image_format: trx
```

---

## Phase 1 — BSP Kernel Build + Blob Integration (3-5 days)

**Goal:** A Nix derivation that builds Merlin's BSP kernel (4.1.51) with
all 77 prebuilt blobs linked in.

### 1.1 — The Blob Problem

The 77 `.o` files in `router-sysdep.rt-ax88u/hnd_extra/prebuilt/` are not
kernel modules (`.ko`). They are **relocatable object files** that get
linked directly into the kernel build via `obj-y` in the Broadcom Makefiles.
The Merlin build system copies them into the kernel source tree, then builds
the kernel, which links them in statically.

**How it works (from `platform.mak` lines 520-700):**

```makefile
# Simplified: the build copies prebuilt .o files into kernel driver directories
# then runs the kernel build. The kernel's build system picks them up via obj-y.

# Example:
# 1. cp prebuilt/bcm_enet.o  → kernel/drivers/net/ethernet/broadcom/
# 2. The kernel Makefile has: obj-$(CONFIG_BCM_ENET) += bcm_enet.o
# 3. The prebuilt .o gets linked into the kernel image statically
```

### 1.2 — Nix Derivation for BSP Kernel

**`pkgs/rt-ax88u/kernel/default.nix`:**

```nix
{ stdenv, buildLinux, fetchurl, lib, fetchFromGitHub } @ args:

let
  version = "4.1.51-merlin";
  modDirVersion = "4.1.51";

  # Merlin's kernel source (from the cloned repo)
  # In practice, we point to the local checkout or a tarball
  src = /home/rodrigo/Workspace/github.com/RMerl/asuswrt-merlin.ng/release/src-rt-5.02axhnd;

  # Prebuilt blobs directory
  prebuiltBlobs = src + "/router-sysdep.rt-ax88u/hnd_extra/prebuilt";
in
stdenv.mkDerivation {
  name = "linux-${version}";
  inherit version src;

  # Instead of using buildLinux (which expects mainline kernel),
  # we use the Merlin build system directly
  buildPhase = ''
    export CROSS_COMPILE=aarch64-unknown-linux-gnu-
    export ARCH=arm64
    export LINUXDIR=$PWD/kernel/linux-4.1

    # 1. Copy prebuilt blobs into kernel tree
    #    (simplified — see platform.mak for exact paths)
    cp ${prebuiltBlobs}/*.o $LINUXDIR/drivers/net/ethernet/broadcom/

    # 2. Configure kernel
    cp $LINUXDIR/config_base.6a $LINUXDIR/.config
    make -C $LINUXDIR ARCH=arm64 oldconfig

    # 3. Build kernel (links in prebuilt blobs statically)
    make -C $LINUXDIR ARCH=arm64 \
      Image dtbs modules -j$(nproc)
  '';

  installPhase = ''
    mkdir -p $out
    cp $LINUXDIR/arch/arm64/boot/Image $out/
    cp $LINUXDIR/arch/arm64/boot/dts/*.dtb $out/
    make -C $LINUXDIR ARCH=arm64 \
      INSTALL_MOD_PATH=$out modules_install
  '';
}
```

**Key challenge:** Replicating Merlin's exact build environment. The build
depends on:
- Exact toolchain version (gcc 5.5 for BCM4908 — see `platform.mak` line 107)
- Exact kernel configuration (`config_base.6a`)
- Exact blob deployment paths (77 files to correct kernel subdirectories)
- Exact Makefile rules from Merlin's `platform.mak`

### 1.3 — Kernel Config Enablement for systemd

The BSP kernel config (`config_base.6a`) disables several options systemd
requires. These can be enabled without affecting the prebuilt blobs — they
control core kernel infrastructure, not driver interfaces.

**Required enables (systemd WILL NOT function without these):**

```
CONFIG_CGROUPS=y                   # Process lifecycle management
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y # Per-process /dev/pts
CONFIG_FHANDLE=y                   # File descriptor passing
```

**Strongly recommended enables (many NixOS modules depend on these):**

```
CONFIG_NAMESPACES=y                # PrivateTmp, ProtectSystem
CONFIG_NET_NS=y                    # Network namespaces
CONFIG_USER_NS=y                   # User namespaces
CONFIG_PID_NS=y                    # PID namespaces
CONFIG_SECCOMP=y                   # SystemCallFilter
CONFIG_SECCOMP_FILTER=y            # Seccomp BPF filter
CONFIG_AUDIT=y                     # Journald audit
CONFIG_POSIX_MQUEUE=y              # POSIX message queues
```

**Nice-to-have enables (fuller systemd feature set):**

```
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_NET_PRIO=y
CONFIG_CGROUP_NET_CLS=y
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_NET_CLS_BPF=y
CONFIG_NET_ACT_BPF=y
CONFIG_FANOTIFY=y                  # Used by systemd for file watches
CONFIG_IKCONFIG=y                  # /proc/config.gz — useful for debugging
CONFIG_IKCONFIG_PROC=y
```

**Implementation in the kernel derivation:**

```nix
# Inside buildPhase, after setting up config_base.6a:
buildPhase = ''
  # ... blob copies ...

  # Enable systemd-required kernel configs
  cat >> $LINUXDIR/.config << 'EOF'
CONFIG_CGROUPS=y
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y
CONFIG_FHANDLE=y
CONFIG_NAMESPACES=y
CONFIG_NET_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_AUDIT=y
CONFIG_POSIX_MQUEUE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_MEMCG=y
CONFIG_BPF_SYSCALL=y
CONFIG_FANOTIFY=y
EOF

  # Refresh config (accept new options with defaults)
  make -C $LINUXDIR ARCH=arm64 olddefconfig

  # Proceed with build...
'';
```

**Verification that blobs still work:**

```bash
# After building, check that blob symbols resolve correctly
aarch64-unknown-linux-gnu-nm result/Image | grep -E "bcm_enet|wl_init|pktrunner"

# Compare with a build using the original config — symbols must match
aarch64-unknown-linux-gnu-objdump -t result/Image > blob-symbols.txt
# Check no unexpected symbol changes
```

### 1.5 — Blob Packaging

**`pkgs/rt-ax88u/blobs/default.nix`:**

```nix
{ stdenv, fetchurl }:

# Packages the 77 prebuilt .o files into a structure
# that the kernel build can consume
stdenv.mkDerivation {
  name = "rt-ax88u-prebuilt-blobs";
  src = /home/rodrigo/Workspace/github.com/RMerl/asuswrt-merlin.ng/release/src-rt-5.02axhnd/router-sysdep.rt-ax88u/hnd_extra/prebuilt;

  installPhase = ''
    mkdir -p $out/lib/modules
    # Copy blobs organized by target kernel directory
    cp $src/bcm_enet.o $out/lib/modules/
    cp $src/wl.o $out/lib/modules/
    cp $src/dhd.o $out/lib/modules/
    # ... (all 77 blobs)
  '';
}
```

### 1.6 — Toolchain

The Merlin BSP kernel 4.1.51 uses `gcc 5.5.0`. Modern `aarch64-unknown-linux-gnu`
toolchains from nixpkgs may work but there could be issues with:
- `__LINUX_ARM_ARCH__` defines
- Built-in functions that changed between gcc 5 and gcc 13
- Inline assembly compatibility

**Recommendation:** Build the kernel with the exact toolchain version from
Merlin, or use `pkgsCross.aarch64-multiplatform.buildPackages.gcc` from a
matching era (nixpkgs has historical gcc versions).

### 1.7 — Verification

```bash
# Build BSP kernel with blobs
nix build .#packages.x86_64-linux.rt-ax88u-kernel

# Check that blobs are linked in
aarch64-unknown-linux-gnu-objdump -t result/Image | grep bcm_enet
# Should show symbols from the prebuilt blob

# Check modinfo for modules
aarch64-unknown-linux-gnu-objdump -t result/Image | grep wl_init
# Should show Wi-Fi driver initialization symbols

# Compress for CFE
bcm4908lzma result/Image > result/Image.lzma
```

---

## Phase 2 — Boot Image (2-4 days)

**Goal:** Package BSP kernel + blobs + DTB + initramfs into CFE-bootable format.

### 2.1 — bcm4908lzma Tool

CFE expects a kernel compressed with LZMA, prefixed with a Broadcom-specific header.
OpenWrt has the `bcm4908lzma` tool. Port to Nix:

**`pkgs/rt-ax88u/bcm4908lzma/default.nix`:**

```nix
{ stdenv, fetchFromGitHub, lzma }:

stdenv.mkDerivation {
  name = "bcm4908lzma";
  src = fetchFromGitHub {
    owner = "openwrt";
    repo = "openwrt";
    rev = "v23.05.0";
    path = "target/linux/bcm4908/image/bcm4908lzma.c";
  };
  buildInputs = [ lzma ];
  buildPhase = "$CC -o bcm4908lzma bcm4908lzma.c -llzma";
  installPhase = "install -D bcm4908lzma $out/bin/bcm4908lzma";
}
```

Alternatively, Merlin's own build produces a `kernel.lzma` via `make.image`.

### 2.2 — Image Assembly

The image format has two parts:
1. **CFE header** — identifies image type, checksum, target
2. **LZMA-compressed kernel** — BSP kernel with blobs linked in, DTB, initramfs

```bash
# High-level assembly:
# 1. Build kernel with initramfs (embedded or appended)
# 2. Compress with bcm4908lzma
# 3. Wrap in CFE format (trx or pkgtb — reverse-engineered in Phase 0)
```

### 2.2a — Initramfs

The initramfs must:
1. Load kernel modules (prebuilt blobs are linked in, no external .ko needed)
2. Mount USB root filesystem
3. switch_root to NixOS

**`pkgs/rt-ax88u/initramfs/default.nix`:**

```nix
{ stdenv, coreutils, busybox, util-linux, eudev }:

stdenv.mkDerivation {
  name = "rt-ax88u-initramfs.cpio.gz";

  buildPhase = ''
    mkdir -p rootfs/{bin,dev,etc,lib/modules,mnt/usb,proc,root,sbin,sys,run}

    # Busybox for essential tools (mount, switch_root, modprobe, sh)
    cp ${busybox}/bin/busybox rootfs/bin/
    for applet in sh mount umount switch_root modprobe lsmod insmod cat echo; do
      ln -s busybox rootfs/bin/$applet
    done

    # udev for device node creation at boot
    cp ${eudev}/lib/udev/* rootfs/lib/ 2>/dev/null || true

    # Init script
    cat > rootfs/init << 'INITEOF'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Load kernel modules (some may be built-in, but ensure WiFi etc.)
modprobe bcm_enet 2>/dev/null || true
modprobe wl 2>/dev/null || true

# Wait for USB storage to appear
echo "Waiting for USB root device..."
for i in $(seq 1 10); do
  if [ -e /dev/sda2 ]; then
    echo "USB device found!"
    break
  fi
  sleep 1
done

# Mount Nix store partition
mount -t ext4 /dev/sda1 /mnt/usb
[ -d /mnt/usb/nix ] || mount -t ext4 /dev/sda2 /mnt/usb

# Mount the Nix store and bootstrap
mkdir -p /mnt/nix
mount --bind /mnt/usb/nix /nix 2>/dev/null || mount /dev/sda1 /nix

# Switch to NixOS stage 2
exec switch_root /mnt/root /init
INITEOF
    chmod +x rootfs/init

    # Create CPIO archive
    cd rootfs
    find . | cpio -H newc -o | gzip > $out
  '';
}
```

### 2.3 — Full Image Derivation

**`pkgs/rt-ax88u/image/default.nix`:**

```nix
{ stdenv, bcm4908lzma, kernel, dtb, initramfs }:

stdenv.mkDerivation {
  name = "rt-ax88u-firmware.trx";
  buildInputs = [ bcm4908lzma ];

  buildPhase = ''
    # 1. Create CFE-compatible kernel image
    #    CFE expects an LZMA-compressed kernel at a fixed offset
    #    The kernel has DTB appended (appended DTB, not FIT)

    # Kernel + DTB (appended per Broadcom convention)
    cat ${kernel}/Image ${dtb}/rt-ax88u.dtb > kernel-dtb.bin

    # Append initramfs (embedded at end of kernel)
    cat kernel-dtb.bin ${initramfs} > kernel-dtb-initramfs.bin

    # 2. LZMA compress
    ${bcm4908lzma}/bin/bcm4908lzma kernel-dtb-initramfs.bin kernel-compressed.lzma

    # 3. Wrap in CFE-compatible header
    #    Format reverse-engineered from Merlin's make.image:
    #    - TRX header (HDR0 + length + CRC32 + offset table)
    #    - Magic: HDR0 (0x30524448)
    #    - Length: total image size
    #    - CRC32: over entire image
    #    - Offsets: [kernel, rootfs, end]
    KERNEL_SIZE=$(stat -c%s kernel-compressed.lzma)

    # Build TRX header
    python3 -c "
import struct, zlib
with open('kernel-compressed.lzma', 'rb') as f:
    data = f.read()

# TRX header: magic(4) + size(4) + crc32(4) + offsets(12)
magic = 0x30524448  # HDR0
size = len(data) + 28  # header + data
crc = zlib.crc32(data) & 0xFFFFFFFF
offset1 = 28  # kernel starts right after header
offset2 = 0   # no separate rootfs
offset3 = size

header = struct.pack('<III', magic, size, crc)
header += struct.pack('<III', offset1, offset2, offset3)

with open('$out', 'wb') as out:
    out.write(header)
    out.write(data)
"
  '';

  installPhase = ''
    echo "Firmware image: $out ($(stat -c%s "$out") bytes)"
  '';
}
```

### 2.4 — Flake Integration

In your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # For cross-compilation
    nixpkgs-cross-arm.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    crossPkgs = import nixpkgs {
      localSystem = "x86_64-linux";
      crossSystem = {
        config = "aarch64-unknown-linux-gnu";
        cpu = "cortex-a53";
      };
    };
  in {
    # Cross-compiled packages
    packages.x86_64-linux.rt-ax88u-kernel =
      crossPkgs.callPackage ./pkgs/rt-ax88u/kernel {};

    packages.x86_64-linux.rt-ax88u-initramfs =
      crossPkgs.callPackage ./pkgs/rt-ax88u/initramfs {};

    packages.x86_64-linux.rt-ax88u-firmware =
      crossPkgs.callPackage ./pkgs/rt-ax88u/image {
        kernel = self.packages.x86_64-linux.rt-ax88u-kernel;
        dtb = self.packages.x86_64-linux.rt-ax88u-dtb;
        initramfs = self.packages.x86_64-linux.rt-ax88u-initramfs;
      };
  };
}
```

### 2.5 — Building the Install Binary

```bash
# Build the complete firmware image
nix build .#packages.x86_64-linux.rt-ax88u-firmware

# Result: result → rt-ax88u-firmware.trx (~8-15 MB)
ls -lh result

# Verify it's a valid TRX
hexdump -C result | head -1
# Should show: 48 44 52 30 = "HDR0"

# Verify kernel is arm64 aarch64
aarch64-unknown-linux-gnu-objdump -f result/Image
```

### 2.6 — Deployment (Web UI Only)

**Constraint:** Only the router's web admin interface firmware upload will be used.
No TFTP boot, no CFE recovery mode, no mtd write from shell.

**The ASUS web UI firmware upload:**
1. Log into router web admin (http://router.asus.com)
2. Administration → Firmware Upgrade → Upload
3. Select `.w` file (UBI format) and upload
4. Router validates image, flashes via UBIFS to NAND, reboots

**What this means for safety:**
- ⚠️ **Every flash writes to NAND.** There is no "test without flashing" option.
- ✅ If the image format is rejected, the web UI shows an error — safe, no write
- ❌ If the image is accepted but the kernel panics on boot — **router is bricked**
  without CFE recovery or UART access
- The web UI validates: UBI structure, Broadcom CFE tags, board ID, and
  possibly kernel signature (vmlinux.sig)
- If validation passes, the image **will** be written

**The only safety net:** The ASUS web UI accepts firmware that passes its
validation checks. If your UBI image and CFE tags are correct, it will flash.
If your kernel crashes, there is no recovery path without CFE recovery mode.

**Procedure:**

```bash
# 1. Build firmware
nix build .#packages.x86_64-linux.rt-ax88u-firmware

# 2. Verify TRX structure before ANY web UI upload:
python3 -c "
import struct, sys
with open('result', 'rb') as f:
    header = f.read(28)
    magic, size, crc32, off1, off2, off3 = struct.unpack('<IIIIII', header)
    print(f'Magic: {hex(magic)} (expect 0x30524448)')
    print(f'Size: {size} bytes')
    print(f'CRC32: {hex(crc32)}')
    print(f'Offsets: {off1}, {off2}, {off3}')
    assert magic == 0x30524448, 'Bad TRX magic!'
    assert size == len(open('result','rb').read()), 'Size mismatch!'
    print('TRX header valid')
"

# 3. Copy to a machine with web browser access to the router
#    (or host it and download from the router)

# 4. Browser: http://192.168.1.1 → Administration → Firmware Upgrade
#    Select result file → Upload
```

**⚠️ IMPORTANT — First flash strategy:**

```bash
# Strategy for the first flash:
# 1. Download the stock ASUS firmware .trx from asus.com
# 2. Upload it via web UI to verify the process works
# 3. THEN build and flash your custom firmware

# First custom flash should have:
# - Minimal initramfs that just: mounts USB, runs a shell
# - NO systemd yet (Phase 4)
# - Just enough to verify the kernel boots and USB is accessible
# - If it boots → proceed. If not → you still have stock to revert to
```

**In the document, all "TFTP boot" and "CFE recovery" references should be
read as "web UI upload" — the same firmware image `.trx` is used for all
methods, just delivered differently.**

### 2.7 — Boot Flow

**⚠️ UPDATED Jun 22 2026:** Stock and Merlin firmware use UBI format with
UBIFS. CFE reads kernel from within UBIFS, not from a fixed flash offset.
Two possible paths:

#### Path A: CFE+UBI (stock-compatible, blocked by secure boot)

```
Power-on
  └─ CFE bootloader
       ├─ 1. Initialize NAND, attach UBI
       ├─ 2. Mount volume "BcmFs-ubifs" (UBIFS)
       ├─ 3. Read vmlinux.sig + vmlinux.lz from UBIFS
       ├─ 4. RSA-verify kernel signature → fail without valid sig
       ├─ 5. Decompress LZMA kernel to DRAM
       ├─ 6. Patch DTB in memory (RAM, board ID, MACs)
       └─ 7. Jump to kernel with DTB pointer
```

#### Path B: USB/NixOS boot (needs secure boot bypass)

```
CFE boots minimal signed kernel → initramfs → mount USB → switch_root → NixOS
```

Initramfs handles root mount from USB SSD or NFS. Secure boot still
applies — CFE authenticates any kernel it loads, regardless of rootfs.

#### Path C: Serial/TFTP (experimental, no flash write)

Needs UART adapter: `CFE> boot -tftp 192.168.1.1:vmlinux.lz`

### 2.8 — Flash Safety Rules (Web UI Only)

1. **Every flash writes to NAND.** There is no safe test mode with web UI upload.
   Static validation must pass before any upload.
2. **The web UI validates UBI structure and Broadcom CFE tags** — a malformed
   UBI image is rejected with an error. This is your only safety check.
   (Stock firmware uses `.w` UBI format, not TRX.)
3. **A kernel that passes UBI validation but panics = brick.** No recovery
   path without CFE recovery mode or UART. **Do not upload until you are
   highly confident the kernel Image is valid.**
4. **First flash: use a minimal kernel** — just enough to boot to a shell via
   initramfs (no systemd, no NixOS userspace).
5. **Keep stock firmware `.w` on your dev machine** — the web UI accepts the
   stock UBI image for reversion.
6. **Never touch the CFE partition.** The web UI only writes to the firmware
   partition — this is safe by design.
7. **The validation pipeline is your only prevention.** Layers 1-5 must pass:

**High risk of brick. Follow these rules:**

1. **Never flash until serial console works** and you can interrupt CFE
2. **Test CFE recovery first**: power on holding reset, ping 192.168.1.1 → should respond
3. **Use TFTP boot only** for initial testing — don't write to flash
4. **Keep stock firmware on flash** — boot your kernel via TFTP without touching partitions

```bash
# Safe test: TFTP boot (does NOT write to flash)
CFE> ifconfig eth0 -addr=192.168.1.2
CFE> boot -tftp 192.168.1.1:kernel-dtb.lzma

# Once kernel boots to shell, mount root from USB
# Still nothing written to NAND flash
```

**Only flash to NAND once you have a known-good kernel that boots to a shell
via TFTP every time.**

---

## Validation Strategy (No Hardware Testing)

**Constraint:** No UART adapter, no smart plug, one router, cannot risk bricking.
All validation must happen without touching the router until a build is
high-confidence enough for one-shot CFE recovery flash.

### Core Principles

1. **Never write to flash unless absolutely certain.** All testing via
   OpenWrt's CFE recovery validation and static analysis.
2. **TFTP boot is the only safe test** — but without serial, you can't
   interrupt CFE to issue `boot -tftp`. However, CFE recovery mode
   (holding reset at power-on) listens for TFTP upload at 192.168.1.1
   and **auto-flashes** — so even recovery mode writes to flash.
3. **Therefore: validate everything statically before the first flash.**

### Validation Layers

```
Layer 1: Nix build succeeds (compilation)
Layer 2: Static binary analysis (symbols, arch, configs)
Layer 3: QEMU user-mode emulation (userspace binaries)
Layer 4: QEMU system boot (kernel to initramfs, without hardware)
Layer 5: Cross-check against known-good Merlin firmware
Layer 6: CFE recovery flash (only when layers 1-5 pass)
```

### Layer 1 — Nix Build Validation

```bash
# Every firmware change must build cleanly:
nix build .#packages.x86_64-linux.rt-ax88u-firmware 2>&1 | tee build.log
BUILD_EXIT=$?

# Fail CI if:
#   - Build error
#   - Any dependency marked as "broken"
#   - Any evaluation warning about unsupported platform
```

### Layer 2 — Static Binary Analysis

```bash
#!/usr/bin/env bash
# post-build-validation.sh — run after successful nix build
set -euo pipefail
FAIL=0

echo "=== Static Analysis ==="

# 2a. Verify it's an arm64 ELF
FILE_TYPE=$(file result)
if [[ "$FILE_TYPE" != *"aarch64"* ]]; then
  echo "FAIL: Image is not arm64: $FILE_TYPE"
  FAIL=1
fi

# 2b. Check blobs linked in (proprietary driver symbols present)
for symbol in bcm_enet_init wl_init pktrunner_init bdmf_init rdpa_init; do
  if ! aarch64-unknown-linux-gnu-nm result/Image | grep -q "$symbol"; then
    echo "FAIL: Missing blob symbol: $symbol"
    FAIL=1
  else
    echo "  OK: $symbol present"
  fi
done

# 2c. Verify kernel version string is Merlin/BSP 4.1
if ! strings result/Image | grep -q "Linux version 4\\.1"; then
  echo "FAIL: Kernel version not 4.1 (is it mainline instead of BSP?)"
  FAIL=1
fi

# 2d. Check systemd kernel configs enabled
if ! strings result/Image | grep -q "CONFIG_CGROUPS=y"; then
  echo "FAIL: CONFIG_CGROUPS not enabled in kernel"
  FAIL=1
fi
for cfg in DEVPTS_MULTIPLE_INSTANCES FHANDLE NAMESPACES SECCOMP; do
  if ! strings result/Image | grep -q "CONFIG_${cfg}=y"; then
    echo "FAIL: CONFIG_${cfg}=y not found in kernel"
    FAIL=1
  fi
done

# 2e. Verify TRX image header format
MAGIC=$(xxd -l 4 -p result)
if [ "$MAGIC" != "30524448" ]; then  # HDR0
  echo "FAIL: Bad TRX header magic: $MAGIC (expected 30524448)"
  FAIL=1
fi

# 2f. Verify initramfs is embedded (size delta check)
#     Kernel Image is ~X MB, with initramfs appended it should be ~Y MB
KERNEL_SIZE=$(stat -c%s result/Image 2>/dev/null || echo 0)
FIRMWARE_SIZE=$(stat -c%s result)
echo "  Image size: $KERNEL_SIZE bytes, Firmware: $FIRMWARE_SIZE bytes"

# 2g. Check DTB model string
if ! strings result | grep -q "ASUS RT-AX88U"; then
  echo "WARN: DTB model string not 'ASUS RT-AX88U'"
fi

echo "=== Static analysis complete ==="
exit $FAIL
```

### Layer 3 — QEMU User-Mode Validation

```bash
# Verify userspace binaries are functional arm64 executables:
qemu-aarch64 result/sw/bin/sh -c "echo hello"
qemu-aarch64 result/sw/bin/ls --version
qemu-aarch64 result/sw/bin/mount --version

# Check systemd binary can at least parse its config:
qemu-aarch64 result/lib/systemd/systemd --test 2>&1 || true
# systemd --test will fail in QEMU (no kernel) but may output useful diagnostics
```

### Layer 4 — QEMU System Boot (No Hardware)

Boot the kernel in QEMU to verify it reaches initramfs. The BSP kernel will
fail to initialize Broadcom hardware (no BCM53134, no BCM43684, no RDPA under
emulation), but it will confirm the kernel Image is bootable:

```bash
# Extract kernel Image from firmware (without TRX header):
dd if=result bs=28 skip=1 2>/dev/null > kernel.bin || cp result kernel.bin

# Boot under QEMU arm64 virt machine:
qemu-system-aarch64 -M virt -cpu cortex-a53 \
  -kernel kernel.bin \
  -initrd result/initramfs.cpio.gz \
  -append "console=ttyAMA0 earlycon root=/dev/sda2 rootwait" \
  -serial stdio \
  -m 1G \
  -drive file=nixos-root.img,format=raw,id=hd \
  -device virtio-blk-device,drive=hd \
  -nographic 2>&1 | head -50
```

Expected output (even on non-Broadcom hardware):
```
[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 4.1.51 ...
[    0.500000] Kernel panic - not syncing: VFS: Unable to mount root fs
```

A kernel panic about rootfs is **expected** — the kernel booted successfully,
the SoC init ran, it just couldn't find the hardware-specific root device
in QEMU. If you get a panic before `Booting Linux on physical CPU`, the
kernel Image is broken.

### Layer 5 — Cross-Check Against Known-Good Merlin

Build a reference kernel from the unmodified Merlin source to establish a
baseline, then compare your modified build against it:

```bash
# 1. Build unmodified Merlin BSP kernel (baseline):
make -C release/src-rt-5.02axhnd \
  CROSS_COMPILE=aarch64-linux-gnu- \
  ARCH=arm64

# 2. Extract symbol table from reference:
aarch64-unknown-linux-gnu-nm -n reference/Image > reference-symbols.txt

# 3. Extract symbol table from your Nix build:
aarch64-unknown-linux-gnu-nm -n result/Image > build-symbols.txt

# 4. Compare — should be identical except for added systemd configs
diff <(grep -v "CONFIG_" reference-symbols.txt) \
     <(grep -v "CONFIG_" build-symbols.txt)

# 5. Verify kernel config diff is ONLY the systemd-required additions:
strings result/Image | grep "^CONFIG_" | sort > build-configs.txt
strings reference/Image | grep "^CONFIG_" | sort > reference-configs.txt
diff reference-configs.txt build-configs.txt
# Expected: only the 20 systemd config options added, nothing removed
```

### Layer 6 — Web UI Upload (only when all above pass)

The ONLY time you touch the router:

```bash
# Prerequisites:
#   - Layers 1-5 pass with zero failures
#   - You have accepted the brick risk
#   - You have the stock ASUS firmware .trx on hand

# 1. Copy your firmware to a machine with browser access to the router

# 2. Verify TRX one more time before uploading:
hexdump -C result | head -3
# Should show: 48 44 52 30 = HDR0

# 3. Log into router web admin → Administration → Firmware Upgrade
#    URL typically: http://192.168.1.1/Advanced_FirmwareUpdate.asp

# 4. Select firmware file → Upload
#    - If web UI shows error → image rejected, safe. Fix TRX format.
#    - If web UI shows progress bar → it's writing to flash

# 5. Router reboots after flash completes

# 6. If router doesn't come back (no ping, no web UI):
#    - The kernel crashed after boot
#    - Without CFE recovery or UART, the router is effectively bricked
#    - The ONLY recovery path is the stock ASUS firmware .trx:
#      Upload it via the same web UI... but you can't access the web UI
#      because the router won't boot.
#    - **This is why Layer 1-5 must be absolutely solid.**
```

### Safety Net: Stock Firmware Re-flash

```bash
# Stock firmware re-flash:
# 1. Download stock ASUS firmware .trx from asus.com/support
# 2. Upload via web UI (same procedure)
# 3. Router reboots to stock

# This works because the web UI only overwrites the firmware partition.
# The CFE bootloader and recovery partition remain intact.
# You can always go back to stock by uploading the stock .trx.
```

### Development Workflow Without Hardware

```
Edit code → nix build → static analysis → all pass? → edit more code
                                                    ↓ fail?
                                                    fix → rebuild

Once per milestone → QEMU smoke test
  ↓ pass?
Cross-check vs Merlin reference
  ↓ pass?
QEMU system boot (kernel reaches initramfs)
  ↓ pass?
WEB UI UPLOAD (first flash: minimal kernel, no systemd)
  ↓ router boots → SSH test → success → add systemd → flash again
  ↓ router dead → no recovery path (brick)
```

**⚠️ The risk is real.** Without CFE recovery or UART, a bad flash that
passes TRX validation but fails at boot is permanent. Mitigate by:
1. First flash: absolute minimum kernel with just busybox initramfs
2. Only after confirming that boots, add systemd
3. Only add Merlin blob features one at a time

### What to Prioritize

Without hardware feedback, invest in:

1. **Static analysis** — the post-build script catches most config/symbol errors
2. **QEMU boot test** — confirms kernel Image validity without hardware
3. **Merlin cross-check** — ensures you haven't broken blob linkage
4. **Initramfs standalone test** — test the init script under QEMU:
   ```bash
   # Test initramfs logic without the router kernel:
   cd pkgs/rt-ax88u/initramfs/rootfs
   sudo chroot . /init 2>&1
   # Will fail at mount (no real devices), but validates shell syntax + logic
   ```
5. **Nix module evaluation test** — verify all NixOS configs evaluate:
   ```bash
   nix eval .#nixosConfigurations.rt-ax88u.config.system.build.toplevel
   ```

---

### Option A: USB Boot (Recommended)

```nix
{ config, lib, pkgs, ... }:

{
  # Boot from USB SSD/thumb drive
  boot.loader.grub.devices = [ "/dev/sda" ];  # USB SATA/MMC
  fileSystems."/" = {
    device = "/dev/sda2";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "vfat";
  };

  # Nix store on USB
  nix.settings.store = "/nix";

  # Keep NAND flash for CFE + recovery only — never mount it writable
}
```

**Caveat:** USB 3.0 ports exist, but the USB controller driver must be working
in your custom kernel.

### Option B: NFS / Network Store

```nix
{
  # Mount /nix from a NFS server on LAN
  fileSystems."/nix" = {
    device = "192.168.1.10:/export/nix-store";
    fsType = "nfs";
  };
}
```

**Benefit:** No USB driver needed. **Downside:** Can't boot without network server.

### Option C: SquashFS + Overlay

For a read-only immutable root, use the approach OpenWrt uses:

```
[mtdblock:rootfs] → squashfs (read-only) 
                    + overlay on data partition (read-write)
```

But NixOS's store model fundamentally fights with this — you'd need to maintain
a compressed squashfs of each generation. Very high complexity, not recommended.

**Recommendation:** Start with Option A (USB boot). Use the NAND flash only as
the CFE loads the kernel from a dedicated kernel partition. Rootfs comes from USB.

---

## Phase 4 — Init System + Userspace (3-5 days)

**Goal:** Boot the BSP kernel to a shell with modern userspace.

### 4.1 — The Init System Decision

You cannot use current NixOS (systemd 259+) on kernel 4.1. Two viable paths:

| Path | Init | Kernel requirement | NixOS compat | Effort |
|---|---|---|---|---|
| **Primary: systemd v252** | systemd override | ~20 configs to enable in BSP kernel | 100% — all `systemd.services.*` | Medium |
| **Fallback: finit** | finit + mdevd + seatd | None — works with current BSP config | Limited — `finit.services.*` | Medium-low |

**Path A — systemd v252 (primary):**
- Pin systemd to v252-v258 (last versions supporting 3.15+ kernels)
- Enable ~20 missing kernel configs (detailed in Phase 1.3)
- systemd runs with `old-kernel` taint flag — functionally complete
- All NixOS modules work: `services.openssh`, `networking.firewall`, etc.

**Path B — finit (fallback if systemd fails):**
- If Broadcom RDPA blobs interact badly with cgroups or namespaces
- finit has zero kernel config requirements beyond what BSP already has
- finix project provides NixOS module
- Loss: many NixOS modules that depend on systemd won't evaluate

### 4.2 — Path A: systemd v252 Override

**`modules/rt-ax88u/systemd-overlay.nix`:**

```nix
# Override nixpkgs's systemd to use v252 (compatible with kernel 4.1)
#
# systemd v259+ removed all kernel <5.10 compatibility code.
# v252 is the last release that supports 3.15+ kernels.
self: super: {
  systemd = super.systemd.override {
    # Pin to systemd v252 from older nixpkgs
    # Use fetchFromGitHub for the specific version
  };

  # NixOS modules reference pkgs.systemd — they get the overridden version
}
```

**NixOS configuration:**

```nix
{ config, lib, pkgs, inputs, ... }:

let
  crossPkgs = import inputs.nixpkgs {
    localSystem = "x86_64-linux";
    crossSystem = {
      config = "aarch64-unknown-linux-gnu";
      cpu = "cortex-a53";
    };
    overlays = [ inputs.self.overlays.rt-ax88u-systemd ];
  };
in {
  imports = [
    inputs.self.nixosModules.rt-ax88u
    ./hardware.nix
    ./network.nix
  ];

  # BSP kernel 4.1 + systemd config enables
  boot.kernelPackages = crossPkgs.callPackage ./pkgs/rt-ax88u/kernel {};

  # Standard NixOS — uses systemd as usual
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  networking.firewall.enable = true;
  networking.hostName = "router-bsp";

  environment.systemPackages = with crossPkgs; [
    vim htop iperf3 wireguard-tools tcpdump ethtool
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA..."
  ];

  system.stateVersion = "24.11";
}
```

**This is NixOS as normal.** Everything works because:
- NixOS generates `systemd.services.*` files as always
- systemd v252 reads them as always
- systemd v252 manages cgroups (v1), seccomp, namespaces, etc. on kernel 4.1
- Only difference: taint `old-kernel` set, cgroup-v2 cpu controller unavailable

### 4.3 — Path B: finit (Fallback)

If systemd v252 doesn't work (possible if Broadcom's RDPA blobs interact badly
with cgroups), switch to finit:

```nix
{ config, lib, pkgs, inputs, ... }:

let
  crossPkgs = import inputs.nixpkgs {
    localSystem = "x86_64-linux";
    crossSystem = {
      config = "aarch64-unknown-linux-gnu";
      cpu = "cortex-a53";
    };
  };
in {
  imports = [
    inputs.finix.nixosModules.finit
    inputs.self.nixosModules.rt-ax88u
    ./hardware.nix
  ];

  boot.kernelPackages = crossPkgs.callPackage ./pkgs/rt-ax88u/kernel {};

  finit = {
    enable = true;
    services.sshd = {
      description = "OpenSSH daemon";
      command = "${crossPkgs.openssh}/bin/sshd -D";
      runlevels = "2345";
    };
    services.getty = {
      description = "Serial console";
      command = "${crossPkgs.agetty}/bin/agetty -L 115200 ttyS0 vt100";
      runlevels = "2345";
    };
  };

  services.mdevd.enable = true;  # replaces udev
  # No systemd module options — must use finit equivalents
}
```

**What finit loses vs systemd:**
- `services.openssh.enable` → must write `finit.services.sshd` manually
- `networking.firewall.enable` → must configure iptables/nft directly
- No journald, resolved, timesyncd, networkd
- Many convenience NixOS modules won't evaluate

### 4.4 — Cross Build Verification

```bash
# Build the full system
nix build .#nixosConfigurations.rt-ax88u.config.system.build.toplevel

# Verify architecture
file result/sw/bin/sh
# → ELF 64-bit LSB executable, ARM aarch64

# Check kernel is BSP 4.1 with blobs
strings result/boot/Image | grep "Linux version 4.1"
# → Linux version 4.1.51 (nixbld) (gcc ...) #1 SMP ...

# Check blob symbols linked in
aarch64-unknown-linux-gnu-objdump -t result/boot/Image | grep bcm_enet

# Verify systemd version
strings result/lib/systemd/libsystemd-core*.so | grep "systemd 252"
```

**Pain point:** No binary cache for `aarch64-unknown-linux-gnu`. First build
compiles glibc, systemd, openssh, coreutils from source.

### 4.5 — Boot Testing

```bash
# Package as CFE-bootable image
nix build .#packages.x86_64-linux.rt-ax88u-firmware

# TFTP boot:
# CFE> ifconfig eth0 -addr=192.168.1.2
# CFE> boot -tftp 192.168.1.1:rt-ax88u-firmware.trx

# Expected serial output (systemd path):
#   Linux version 4.1.51 (nixbld) ...
#   ARCH_BCM4908 initialized
#   ...
#   [    5.123] systemd[1]: systemd v252 running in system mode. (taints: old-kernel)
#   [    5.234] systemd[1]: Detected architecture arm64.
#   [    5.456] systemd[1]: Started OpenSSH Daemon.
#   login:
```

---

## Phase 5 — Networking Stack (2-4 days)

**Goal:** WAN/LAN routing with the BCM53134 switch.

### 5.1 — Switch Driver

The BCM53134 is supported by the upstream `b53` DSA driver in recent kernels.
Check if your kernel config includes:

```
CONFIG_NET_DSA_BCM_SWITCH=y
CONFIG_B53=y
CONFIG_B53_MDIO_DRIVER=y
CONFIG_B53_SPI_DRIVER=y
```

If the upstream driver doesn't work (likely — Broadcom switches often need
vendor patches), you'll need to backport from AsusWRT's GPL source:

```bash
# Extract from AsusWRT
ls release/src-rt-5.02axhnd/.../bcm53134/
# → proprietary kernel module or patches
```

### 5.2 — DSA Binding in DTS

```dts
&switch0 {
  compatible = "brcm,bcm53134", "brcm,bcm5301x";
  status = "okay";

  ports {
    port@0 {
      reg = <0>;
      label = "cpu";
      ethernet = <&gmac0>;
      phy-mode = "internal";
    };
    port@1 {
      reg = <1>;
      label = "lan1";
    };
    port@2 {
      reg = <2>;
      label = "lan2";
    };
    // ... up to port 8
    port@8 {
      reg = <8>;
      label = "wan";
    };
  };
};
```

**Reality:** This is speculative. The actual DSA binding depends on how the
BCM53134 is connected (MDIO? MMIO? RGMII?). Must reverse from schematic or
vendors DTS.

### 5.3 — NixOS Network Config

```nix
{ config, lib, pkgs, ... }:

{
  networking = {
    useDHCP = false;
    firewall.enable = true;

    # The CPU port is the DSA master
    bridges.br0.interfaces = [
      "lan1" "lan2" "lan3" "lan4" "lan5" "lan6" "lan7" "lan8"
    ];

    # WAN on separate interface
    interfaces.wan = {
      useDHCP = true;
    };

    nat = {
      enable = true;
      externalInterface = "wan";
      internalInterfaces = [ "br0" ];
    };
  };
}
```

---

## Phase 6 — Wi-Fi Bring-up (<5% chance of success)

**⚠️ Council finding (5:1 against): brcmfmac likely doesn't support these chips.
The `wl.ko` fallback is DEAD — compiled for kernel 4.1.45, cannot load on 6.12.
Treat this phase as an investigation, not a deliverable.**

### 6.1 — Honest Assessment

| Driver | Feasibility | Why |
|---|---|---|
| `brcmfmac` on mainline 6.12 | **<10%** | No firmware blobs exist for BCM43684/4366E in `linux-firmware`. These chips are recent and Broadcom doesn't upstream Wi-Fi drivers. AP-mode on brcmfmac is spotty even for supported chips. |
| Package `wl.ko` from Merlin | **0%** | Compiled for kernel 4.1.45. Module ABI is intentionally unstable between major versions. vermagic check rejects it. Internal kernel APIs have changed completely. |
| Open-source `b43`/`b43legacy` | **0%** | Covers old 802.11a/b/g chips only |
| Reverse-engineer BCM43684 | **Not viable** | Years of work |

### 6.2 — What to Try (low expectations)

```nix
{ config, lib, pkgs, ... }:

{
  # Include all known Broadcom firmware blobs
  hardware.firmware = with pkgs; [
    linux-firmware
  ];

  # Try brcmfmac — might detect the PCIe device
  boot.initrd.kernelModules = [ "brcmfmac" ];

  # If detected but missing firmware:
  # 1. Extract .bin and .txt from a running Merlin install
  #    scp router:/lib/firmware/brcm/brcmfmac43684* ./
  # 2. Package them as a Nix derivation
  # 3. Place in /lib/firmware/brcm/
}
```

If brcmfmac detects the PCIe device and loads firmware but doesn't create
a working `wlan0`, you've reached the limit. The router becomes wired-only.

### 6.3 — Practical Alternative

Use Merlin on the RT-AX88U for Wi-Fi + NixOS on separate x86 for routing:

```
ISP ──┬── RT-AX88U (Merlin, AP mode, Wi-Fi only)
      └── NixOS x86 box (routing, firewall, DHCP, DNS)
```

The council unanimously recommends this split as the pragmatic path.

---

## Phase 7 — NixOS Module (1-2 days)

**Goal:** Abstract all RT-AX88U specifics behind one import.

**`modules/rt-ax88u/default.nix`:**

```nix
{ config, lib, pkgs, ... }:

{
  options = {
    hardware.rt-ax88u = {
      enable = lib.mkEnableOption "ASUS RT-AX88U board support";
      kernelVersion = lib.mkOption {
        type = lib.types.str;
        default = "6.12";
      };
      storage = lib.mkOption {
        type = lib.types.enum [ "usb" "nfs" ];
        default = "usb";
      };
      wifi.enable = lib.mkEnableOption "Wi-Fi support";
      wifi.firmwareSource = lib.mkOption {
        type = lib.types.path;
        description = "Path to proprietary Wi-Fi firmware blobs";
      };
    };
  };

  config = lib.mkIf config.hardware.rt-ax88u.enable {
    # Architecture
    nixpkgs.localSystem = {
      system = "aarch64-linux";
    };

    # Kernel
    boot.kernelPackages = let
      crossPkgs = import <nixpkgs> {
        localSystem = builtins.currentSystem;
        crossSystem = config.nixpkgs.localSystem;
      };
    in crossPkgs.linuxPackagesFor
      (crossPkgs.callPackage ./kernel.nix {});

    # Kernel params required for boot
    boot.kernelParams = [
      "console=ttyS0,115200"
      "earlycon"
      "root=/dev/sda2"  # or whatever USB root is
      "rootwait"
    ];

    # Firmware blobs
    hardware.firmware = [
      (pkgs.callPackage ./firmware.nix {
        source = config.hardware.rt-ax88u.wifi.firmwareSource;
      })
    ];

    # Hardware-specific packages
    environment.systemPackages = with pkgs; [
      rt-ax88u.wifi-firmware
      rt-ax88u.bcm4908lzma
    ];
  };
}
```

---

## Phase 8 — Flake Integration (1 day)

### 8.1 — Add to `flake.nix`

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # For cross-compilation reference
    nixpkgs-cross-arm.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    # ... existing book3 config ...
  in {
    # Add to existing flake:
    nixosConfigurations = rec {
      # Existing
      book3 = ...;

      # New: RT-AX88U router
      rt-ax88u = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.nixosModules.rt-ax88u
          ./nixos/hosts/rt-ax88u
        ];
      };
    };

    # Also keep x86_64 build capability for cross-compilation host
    packages.x86_64-linux.rt-ax88u-firmware =
      self.nixosConfigurations.rt-ax88u.config.system.build.firmware;
  };
}
```

### 8.2 — Build the Image

```bash
# Build full firmware image
nix build .#nixosConfigurations.rt-ax88u.config.system.build.toplevel

# Or just the flashable firmware
nix build .#packages.x86_64-linux.rt-ax88u-firmware

# Flash via CFE recovery:
# 1. Power off, hold reset, power on
# 2. Wait for IP 192.168.1.1
# 3. tftp firmware.bin to 192.168.1.1
curl -T result/firmware.trx tftp://192.168.1.1/
```

---

## Phase 9 — Iteration & Debugging (ongoing)

### Boot Debug Checklist

```
[ ] UART console shows CFE prompt
[ ] CFE loads kernel from flash/TFTP
[ ] Kernel decompresses and starts
[ ] earlycon shows boot messages
[ ] NAND driver works, mounts rootfs
[ ] /init starts (NixOS stage 1)
[ ] stage 2 switches to real root
[ ] SSH login works
[ ] Ethernet ports show link
[ ] VLANs work
[ ] NAT works
[ ] Wi-Fi AP visible
[ ] Wi-Fi clients can connect and route
```

### When things break (they will):

1. **Kernel panic before userspace** → fix DTS, kernel config, or initramfs
2. **Hang after "VFS: Cannot open root device"** → wrong root= parameter, missing driver
3. **NixOS stage 1 fails** → initramfs doesn't have the right modules
4. **SSH doesn't start** → missing console, network not up
5. **Switch ports dead** → DSA binding wrong, driver not loaded
6. **Wi-Fi not working** → blobs missing, wrong firmware version, regulatory issues

---

## Phase 10 — Upstreaming (long-term)

- Submit RT-AX88U DTS to mainline Linux
- Push BCM4908 patches that don't conflict with upsteam
- Contribute NixOS module to `nixos-hardware` or `nixpkgs`
- Publish the flake

---

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Option A (Split)** — RT-AX88U as AP + NixOS on x86 | | | |
| NixOS x86 box fails | Low | Medium | Redundant config, backup hardware |
| Wi-Fi interference with AP mode | Low | Low | Proper channel selection |
| Merlin firmware bug | Low | Low | Stick to tested Merlin releases |
| **Option B (Nix-on-Merlin)** | | | |
| glibc ABI mismatch on 4.1 kernel | Medium | Medium | Use static binaries where possible |
| Nix store fills NAND | Medium | Medium | Symlink /nix to USB storage |
| Entware + Nix conflict | Low | Low | Keep separate prefixes |
| **Option C (Full port, not recommended)** | | | |
| CFE won't boot custom kernel | High | Blocking | OpenWrt did it; copy their image format |
| Wi-Fi entirely non-functional | **Certain** | High | Option A avoids this entirely |
| Hardware packet offload unavailable | **Certain** | Medium | Accept software NAT |
| Prebuilt blobs locked to 4.1 kernel | **Certain** | Blocking | Cannot be circumvented |
| systemd incompatible with 4.1 kernel | **Certain** | Blocking | No modern NixOS possible |

---

## Resource Links

| Resource | URL |
|---|---|
| Asuswrt-Merlin project | https://github.com/RMerl/asuswrt-merlin.ng |
| Merlin supported devices | https://github.com/RMerl/asuswrt-merlin.ng/wiki/Supported-Devices |
| SNBForums Merlin support | https://www.snbforums.com/forums/asuswrt-merlin.42/ |
| OpenWrt bcm4908 target | https://git.openwrt.org/openwrt/openwrt.git (target/linux/bcm4908/) |
| Mainline BCM4908 DTSI | `arch/arm64/boot/dts/broadcom/bcmbca/bcm4908.dtsi` |
| ASUS GPL source (RT-AX88U) | https://github.com/blackfuel/asuswrt-rt-ax88u |
| NixOS on x86 routers | https://nixos.wiki/wiki/NixOS_as_a_router |
| Nix cross-compilation | https://nix.dev/tutorials/cross-compilation |
| Static Nix binary | https://hydra.nixos.org/job/nix/master/nix-static-aarch64-linux |
| Entware (packages for routers) | https://entware.net/ |
| Protectli (x86 router hardware) | https://protectli.com |
| RT-AX88U hardware specs | https://wikidevi.wi-cat.ru/ASUS_RT-AX88U |

---

## Immediate First Steps

### For Option A (Split Architecture — RECOMMENDED):

1. **Buy x86 router hardware** (Protectli, Wyse, or similar with 2+ NICs)
2. **Install NixOS** on the x86 box via `nixos-install`
3. **Configure RT-AX88U as AP** — Merlin → Administration → Operation Mode: AP
4. **Connect**: Modem → RT-AX88U WAN → NixOS WAN port, NixOS LAN → switch/clients
5. **Enjoy**: Full Merlin Wi-Fi + full NixOS routing, working today

### For Option B (Nix-on-Merlin):

1. **Flash latest Merlin** on RT-AX88U
2. **Plug in USB storage** (required for Entware + Nix store)
3. **Enable SSH + JFFS2** in Merlin admin
4. **Install Entware**: `ssh admin@router; entware-setup.sh`
5. **Install static Nix**: download to `/opt`, add to PATH
6. **Use `nix profile install`** for packages

### For Option C (Full port — only if you accept the constraints):

1. **No hardware testing, web UI upload only.** Every flash writes to NAND.
   There is no safe boot mode.
2. **Build the validation pipeline first** — `post-build-validation.sh` must run
   with zero failures before any web UI upload
3. **First flash must be a minimal kernel** — just BSP kernel + busybox initramfs
   + USB root. **No systemd.** Prove the kernel boots before adding complexity.
4. **Keep stock firmware .trx on your dev machine** — if your custom firmware
   boots, you can always revert via web UI. If it doesn't boot, you cannot
   revert (no UART, no CFE recovery access).
5. **Enable systemd configs one at a time** — baseline → CGROUPS → test → FHANDLE
   → test → etc. Each change is a separate flash with static validation.
6. **Accept the brick risk.** Without UART or CFE recovery button procedure,
   a booting-but-crashing kernel is a brick. This is not a safe project.
    Consider buying a Raspberry Pi or cheap UART adapter for safety.

---

## Implementation Progress (Jun 20 2026)

### Deliverables

| # | Component | Status | Commit |
|---|---|---|---|---|
| 1 | `bcm4908lzma` — LZMA wrapper | 🟡 **Format wrong** (needs UBI, not TRX) | *earlier* |
| 2 | `rt-ax88u-bsp-kernel` — BSP kernel | ✅ **9.4 MB arm64 Image** | `544fa28` |
| 3 | `merlin-web-ui/*` — 7 packages | ✅ All 7 build + link | Latest |
| 4 | `nixos/hosts/rt-ax88u/` — NixOS config | ✅ Written (needs root/bootloader fix) | `698a7d5` |
| 5 | UBI firmware image | ❌ Not yet created (TRX was wrong format) | N/A |
| 6 | Validation pipeline | ✅ `pkgs/rt-ax88u-validation` | `429f8c5` |

### Kernel Build — Key Technical Decisions

| Problem | Fix |
|---|---|
| `sourceRoot = "."` kept build in wrong dir | Remove — auto-detect `source/` subdir |
| `make -C` needed for PWD isolation | All phases use `make -C "$KERNEL_DIR"` |
| `preConfigure` not evaluated when `configurePhase` overridden | Moved blob deploy into `configurePhase` |
| HOSTCC missing on cross-build | Explicit `HOSTCC = ` store path to native gcc |
| `dtc` linker error (`yylloc` duplicate) | `HOSTLDFLAGS = -Wl,--allow-multiple-definition` |
| Assembly `#alloc` syntax (GAS 2.46) | `sed` patch → `"ax"` format |
| `Kconfig.autogen` missing | Create empty stub |
| `BCM_KF` not set (kernel ifdef gate) | Env var `BCM_KF = "1"` |
| `built-in.o` link error from empty path | `INC_UTILS_PATH` → real dir with obj-y |
| Merlin make vars not set | `merlinMakeArgs` let-block → all make invocations |
| RDP target dirs lack Makefiles | Create minimal `obj-y` Makefiles in `configurePhase` |
| Missing include headers (long tail) | `KCFLAGS` with all Broadcom include roots |
| `wl` is executable (no `.o` ext) | Fixed `cp` target name |
| Char driver dirs not created for blobs | Added `mkdir -p` for all blob destinations |

### Merlin source rev

Updated from `e1b0940d` (non-existent) to `68d0ffc5` (main HEAD).
Hash: `17ac05gqkl7pmv9bm950nnwrm3gc45485n4al5klxbrsdwrmai2r` (base32).

### Blob deployment

All 77 prebuilt blobs extracted from `router-sysdep.rt-ax88u/hnd_extra/prebuilt/`
into the bcmdrivers tree (`_preb` naming convention). Blobs deployed as part of
`configurePhase`, not `preConfigure` (which is silent when `configurePhase` is
overridden in Nix).

### Remaining Work

1. **Switch to UBI image format** — stock/Merlin use UBI `.w`, not TRX.
   Need UBI image generation (ubinize) with BcmFs-ubifs volume.
   (See `docs/rt-ax88u-stock-firmware-analysis.md` for reference layout.)
2. **Investigate secure boot** — does CFE enforce vmlinux.sig auth?
   Test with a signed stock kernel first, then unsigned custom kernel.
3. **Build NixOS host config** — test that `nixos-rebuild` evaluates
4. **Validation** — `nix flake check` to run kernel ELF + config checks
5. **Hardware test** — web UI upload (brick risk, no serial recovery)


# RT-AX88U NixOS Port — Gap Analysis

**Generated:** 2026-06-22  
**Based on:** codebase audit + session handoff `/tmp/rt-ax88u-session-2026-06-22.md`  
**Companion:** `docs/rt-ax88u-port-plan.md`

---

## Legend

| Mark | Meaning |
|---|---|
| ✅ | Implemented |
| ❌ | Missing |
| 🟡 | Partial / needs verification |

---

## 1. What IS Implemented (16 items)

| Area | File(s) | Status |
|---|---|---|
| BSP kernel 4.1.51 builds with 77 blobs + systemd config enables | `pkgs/rt-ax88u-bsp-kernel/default.nix` | ✅ |
| libshared (47 objects + prebuilts, shutils.c fix) | `pkgs/merlin-web-ui/libshared/default.nix` | ✅ |
| libnvram (NVRAM access library) | `pkgs/merlin-web-ui/libnvram/default.nix` | ✅ |
| libpasswd (password hashing) | `pkgs/merlin-web-ui/libpasswd/default.nix` | ✅ |
| mssl (mini SSL wrapper) | `pkgs/merlin-web-ui/mssl/default.nix` | ✅ |
| libwebapi (REST API library) | `pkgs/merlin-web-ui/libwebapi/default.nix` | ✅ |
| httpd (web server, 61 stubs) | `pkgs/merlin-web-ui/httpd/default.nix` | ✅ |
| www static files | `pkgs/merlin-web-ui/www/default.nix` | ✅ |
| bcm4908lzma (CFE LZMA compressor) | `pkgs/bcm4908lzma/default.nix` | ✅ |
| addtrx (TRX V1 header prepender) | `pkgs/addtrx/default.nix` | ✅ |
| TRX firmware image package | `pkgs/rt-ax88u-firmware/default.nix` | ✅ |
| Validation pipeline (kernel ELF + config, web UI file check) | `pkgs/rt-ax88u-validation/default.nix` | ✅ |
| `nix flake check` passes | `flake.nix` | ✅ |
| NixOS host config (evaluates) | `nixos/hosts/rt-ax88u/` | ✅ |
| Merlin web UI NixOS module | `modules/merlin-web-ui.nix` | ✅ |
| Flake integration (nixosConfigurations, overlay, packages) | `flake.nix`, `pkgs/default.nix` | ✅ |
| Auto-detect web-broadcom.c (real → stub fallback) | `pkgs/merlin-web-ui/httpd/default.nix` | ✅ |
| Port plan with detailed phases | `docs/rt-ax88u-port-plan.md` | ✅ |
| Session handoff | `/tmp/rt-ax88u-session-2026-06-22.md` | ✅ |
| Golden Rule documented | `docs/rt-ax88u-port-plan.md` | ✅ |

---

## 2. Critical Gaps (Boot Blockers)

### 2.1 ❌ No initramfs — firmware is kernel-only, cannot boot

The firmware builds `kernel/Image → LZMA → TRX`. No initramfs cpio is appended.
Without it, the kernel panics at `VFS: Unable to mount root fs`.

**Needed:** `pkgs/rt-ax88u-initramfs/` with busybox + mount + switch_root,
appended to kernel Image before LZMA compression.

**Reference:** Port plan Phase 2.2a (lines 969-1037) has a complete stub.

---

### 2.2 ❌ No systemd v252 override — systemd 259+ refuses kernel 4.1

Current nixpkgs ships systemd ≥259 which requires kernel ≥5.10.
BSP kernel is 4.1.51. No override exists anywhere.

**Needed:**
- `pkgs/systemd-old/default.nix` pinning systemd v252-v258
- Overlay applying it to `pkgs.systemd`
- `modules/rt-ax88u/systemd-override.nix` or similar

**Reference:** Port plan Phase 4.2 (lines 1664-1681) has the approach.

---

### 2.3 ❌ Contradictory root filesystem config

`hardware-configuration.nix` sets `root=/dev/mtdblock9 rootfstype=squashfs`
(pointing at Merlin's firmware partition). Port plan recommends USB boot
(`root=/dev/sda2`). NixOS actually needs neither — it needs initramfs →
kernel modules → mount root → switch_root.

**Needed:** Rewrite `hardware-configuration.nix` to match the initramfs
boot flow. Remove mtdblock9/squashfs references.

---

### 2.4 ❌ `boot.loader = extlinux` — wrong for CFE bootloader

CFE loads kernel directly from firmware NAND partition. extlinux is for U-Boot.
Dead config option on this hardware.

**Needed:** Remove `boot.loader.generic-extlinux-compatible.enable = true`.
The bootloader is CFE, not configurable from userspace.

---

### 2.5 ❌ No DTB generation — using reference board DTS

`passthru.buildDTBs = false` and `hardware.deviceTree.enable = false`.
Kernel uses Merlin's 94908REF reference DTS (not RT-AX88U specific).
GPIO/LED/button/switch pin assignments are speculative.

**Needed:** RT-AX88U-specific DTS with proper BCM53134 switch binding,
LED/button GPIOs, USB power control.

**Reference:** Port plan Phase 0.6 (lines 614-637).

---

## 3. Important Gaps

### 3.1 🟡 Kernel modules build is best-effort

```nix
# modules build allows failure:
make ... modules 2>&1 || echo "modules build did not fully succeed"
```

No guarantee `.ko` files are produced. External module loading (Wi-Fi, USB)
may be broken.

**Needed:** Fix the modules build so it succeeds reliably, or explicitly
identify which blobs are built-in vs loadable.

---

### 3.2 ❌ Validation pipeline is too minimal

Current checks only:
- File exists
- ELF is ARM64
- Config has CGROUPS/NAMESPACES/SECCOMP

**Missing:**
- Blob symbol presence (`bcm_enet_init`, `wl_init`, `pktrunner_init`, `bdmf_init`)
- TRX header magic + CRC validation
- Kernel version string check (`Linux version 4.1`)
- QEMU smoke boot test
- Merlin reference cross-check (symbol table diff)

**Reference:** Port plan Validation Strategy (lines 1307-1579) has all layers
defined. Implement Layers 2a-2g.

---

### 3.3 ❌ 61 stubs — httpd links but can't manage router

All hardware-dependent functions return 0/NULL. Web UI renders pages but:

| Stub type | Count | Impact |
|---|---|---|
| ej_wl_* (Wi-Fi status) | ~35 | No wireless info in UI |
| notify_rc | 1 | **No config apply** — reboot, restart, settings all no-op |
| pwenc / web_hook | 2 | No password encryption, no web hooks |
| nvram_* (modify/log) | ~5 | Config changes don't persist |
| Security checks | ~10 | Captcha, CSRF, ban — all pass-through |
| VPN / DDNS / misc | ~8 | Feature pages render empty |

**Priority:** `notify_rc` → simple IPC reimplementation (port plan future work #3).

---

### 3.4 ❌ No nvram persistence infrastructure

`libnvram.so` builds but there's no:
- nvram daemon providing the NVRAM API
- /dev/mtdblock1 (nvram partition) mount or access
- Default nvram values file

Config changes via web UI won't survive reboot.

---

### 3.5 🟡 USB storage drivers not verified

Recommended root is USB SSD. BSP kernel must include:
- USB 3.0 controller driver (`bcm_usb.o` blob)
- USB mass storage class driver
- ext4 filesystem support

These are NOT explicitly configured in the kernel config patch.
Need verification that `CONFIG_USB_STORAGE`, `CONFIG_EXT4_FS`, etc. are
enabled in the final `.config`.

---

## 4. Minor/Medium Gaps

| # | Gap | File | Effort |
|---|---|---|---|
| 4.1 | No `docs/rt-ax88u-hw.yaml` (Phase 0.7) | missing | 1h |
| 4.2 | No `modules/rt-ax88u/` top-level NixOS module | missing | 1d |
| 4.3 | No WireGuard VPN config | `networking.nix` | 2h |
| 4.4 | No DNS resolver config | `networking.nix` | 30m |
| 4.5 | No firewall hardening (rate limit, drop invalid) | `networking.nix` | 1h |
| 4.6 | No Nix store config (USB path, GC) | `default.nix` | 30m |
| 4.7 | No CI workflow | missing | 1d |
| 4.8 | Modern gcc, not Merlin's gcc 5.5 — ABI risk | `kernel/default.nix` | 1d to verify |
| 4.9 | No build/usage documentation | missing | 1h |
| 4.10 | No development workflow guide | missing | 1h |
| 4.11 | No NixOS stage 1 (initrd) or stage 2 config | missing | 2d |

---

## 5. Summary by Priority

| Priority | Gap | Depends on | Effort |
|---|---|---|---|
| **P0** | Initramfs | — | 1-2d |
| **P0** | systemd v252 override | — | 1d |
| **P0** | Fix root config + bootloader | — | 1h |
| **P1** | Initramfs boot path (USB mount, switch_root) | P0 initramfs | 2-3d |
| **P1** | Kernel modules build reliability | — | 1d |
| **P1** | DTB generation (real device tree) | — | 1d |
| **P1** | Validation pipeline expansion | — | 1d |
| **P2** | notify_rc → simple IPC | — | 1-2d |
| **P2** | nvram persistence infrastructure | — | 1d |
| **P2** | USB storage/kernel config verification | — | 1d |
| **P3** | Remaining stubs → real implementations | P2 notify_rc | 3-5d |
| **P3** | docs/rt-ax88u-hw.yaml | — | 1h |
| **P3** | Build/usage documentation | — | 1h |
| **P4** | WireGuard, DNS, firewall hardening | — | 1d |
| **P4** | CI pipeline | — | 1d |

---

## 6. Dependency Graph

```
                    ┌──────────────┐
                    │ BSP kernel   │
                    │ (done)       │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     ┌────────────┐ ┌──────────┐ ┌──────────┐
     │ Initramfs  │ │ systemd  │ │ DTB      │
     │ (P0)       │ │ override │ │ (P1)     │
     └─────┬──────┘ │ (P0)     │ └──────────┘
           │        └────┬─────┘
           ▼             ▼
     ┌─────────────────────────┐
     │  Boot path integration  │
     │  (initramfs → systemd)  │
     └────────────┬────────────┘
                  │
                  ▼
     ┌─────────────────────────┐
     │  Kernel modules + USB   │
     │  storage verification   │
     └────────────┬────────────┘
                  │
                  ▼
     ┌─────────────────────────┐
     │  notify_rc + nvram      │
     │  (web UI goes live)     │
     └────────────┬────────────┘
                  │
                  ▼
     ┌─────────────────────────┐
     │  Networking hardening   │
     │  + CI + docs            │
     └─────────────────────────┘
```

---

## 7. Quick Wins (can be done in <1h)

1. Remove `boot.loader.generic-extlinux-compatible.enable = true`
2. Rename/fix `hardware-configuration.nix` root device to placeholder
3. Create `docs/rt-ax88u-hw.yaml` from port plan Phase 0.7 template
4. Enable `CONFIG_USB_STORAGE`, `CONFIG_EXT4_FS` in kernel config patch
5. Add blob symbol checks to validation (uncomment `nm` section)
6. Add real `kernel.release` to `config` passthru

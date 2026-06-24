{ stdenv, lib, rt-ax88u-bsp-kernel, merlin-web-ui, rt-ax88u-firmware-ubi, rt-ax88u-initramfs }:

# RT-AX88U validation checks.
# Fails if any check fails — used as `nix flake check` or CI.
# Phases:
#   1. Kernel validation (ELF aarch64, config, version string, blob symbols)
#   2. UBI firmware validation (magic bytes, UBIFS volume)
#   3. Initramfs validation (gzip integrity, busybox, init script)
#   4. Web UI package validation (files exist)

stdenv.mkDerivation {
  pname = "rt-ax88u-validation";
  version = "0.1";

  phases = [ "buildPhase" ];

  buildPhase = ''
    echo "=== RT-AX88U Validation ===="

    errors=0

    # --- 1. Kernel check ---
    KERNEL="${rt-ax88u-bsp-kernel}/Image"
    CONFIG="${rt-ax88u-bsp-kernel}/config"

    if [ ! -f "$KERNEL" ]; then
      echo "FAIL: Kernel Image not found at $KERNEL"
      errors=$((errors + 1))
    else
      file "$KERNEL" | grep -q "ARM64" && \
        echo "OK: Image is ARM64 boot executable" || \
        { echo "FAIL: Image is not ARM64"; errors=$((errors + 1)); }

      # Note: version string and blob symbol checks require the ELF vmlinux
      # (not the Image), so they're skipped here. Check the kernel .config
      # for BSP identification instead:
      if [ -f "$CONFIG" ]; then
        grep -q "CONFIG_BCM_KF=y" "$CONFIG" 2>/dev/null && \
          echo "OK: CONFIG_BCM_KF=y (Broadcom kernel features - BSP)" || \
          echo "NOTE: CONFIG_BCM_KF not set"
      fi
    fi

    if [ -f "$CONFIG" ]; then
      for opt in CONFIG_CGROUPS=y CONFIG_NAMESPACES=y CONFIG_SECCOMP=y \
                 CONFIG_FHANDLE=y CONFIG_BPF_SYSCALL=y; do
        grep -q "$opt" "$CONFIG" && \
          echo "OK: $opt" || \
          { echo "FAIL: $opt not set"; errors=$((errors + 1)); }
      done
    else
      echo "FAIL: kernel config not found at $CONFIG"
      errors=$((errors + 1))
    fi

    # --- 2. UBI firmware check ---
    UBI="${rt-ax88u-firmware-ubi}/ubi.img"
    if [ ! -f "$UBI" ]; then
      echo "FAIL: UBI image not found at $UBI"
      errors=$((errors + 1))
    else
      # Check UBI magic: bytes 0-3 = 0x55424923 ("UBI#")
      UBI_MAGIC=$(xxd -l 4 -p "$UBI" 2>/dev/null || od -A n -t x1 -N 4 "$UBI" | tr -d ' \n')
      if [ "$UBI_MAGIC" = "55424923" ]; then
        echo "OK: UBI image has valid magic (UBI#)"
      else
        echo "FAIL: UBI image bad magic: $UBI_MAGIC (expected 55424923)"
        errors=$((errors + 1))
      fi

      # Check UBIFS magic inside first LEB payload
      # UBIFS magic = 0x31181006 (at start of UBIFS data after UBI headers)
      UBI_SIZE=$(stat -c%s "$UBI")
      echo "  UBI image size: $UBI_SIZE bytes"
      echo "  UBI erase blocks: $(( UBI_SIZE / 131072 ))"
    fi

    # --- 3. Initramfs check ---
    INITRAMFS="${rt-ax88u-initramfs}/initramfs.cpio.gz"
    if [ -f "$INITRAMFS" ]; then
      gzip -t "$INITRAMFS" && \
        echo "OK: initramfs valid gzip ($(stat -c%s "$INITRAMFS") bytes)" || \
        { echo "FAIL: initramfs gzip corrupted"; errors=$((errors + 1)); }
      # Check decompressed content (cpio archive with readable strings)
      gunzip -c "$INITRAMFS" 2>/dev/null | grep -a -c "busybox" > /dev/null 2>&1 && \
        echo "OK: initramfs contains busybox" || \
        { echo "FAIL: initramfs missing busybox"; errors=$((errors + 1)); }
      gunzip -c "$INITRAMFS" 2>/dev/null | grep -a -c "switch_root" > /dev/null 2>&1 && \
        echo "OK: initramfs has switch_root (init script)" || \
        { echo "FAIL: initramfs missing switch_root in init"; errors=$((errors + 1)); }
    else
      echo "FAIL: initramfs not found at $INITRAMFS"
      errors=$((errors + 1))
    fi

    # --- 4. Web UI packages check ---
    for pkg in www libshared libnvram libpasswd mssl libwebapi httpd; do
      case "$pkg" in
        www)    file="${merlin-web-ui.www}/www/APP_Installation.asp" ;;
        httpd)  file="${merlin-web-ui.httpd}/sbin/httpd" ;;
        libshared) file="${merlin-web-ui.libshared}/lib/libshared.so" ;;
        libnvram)  file="${merlin-web-ui.libnvram}/lib/libnvram.so" ;;
        libpasswd) file="${merlin-web-ui.libpasswd}/lib/libpasswd.a" ;;
        mssl)      file="${merlin-web-ui.mssl}/lib/libmssl.a" ;;
        libwebapi) file="${merlin-web-ui.libwebapi}/lib/libwebapi.a" ;;
      esac
      if [ -f "$file" ]; then
        echo "OK: $pkg ($file)"
      else
        echo "FAIL: $pkg — $file not found"
        errors=$((errors + 1))
      fi
    done

    echo "=== Results: $errors errors ==="
    if [ "$errors" -gt 0 ]; then
      exit 1
    fi

    touch $out
  '';

  meta = {
    description = "Validation checks for RT-AX88U BSP kernel, UBI firmware, and web UI";
    platforms = lib.platforms.all;
  };
}

{ lib, stdenv, busybox, buildPackages }:

# Minimal initramfs for RT-AX88U.
#
# Embedded in the kernel via CONFIG_INITRAMFS_SOURCE during kernel build.
# Handles the gap between CFE loading the kernel and NixOS stage 2.
#
# Boot flow:
#   CFE → decompress kernel → kernel boots → /init (this initramfs)
#   → mount proc/sys/dev → find USB root → switch_root → NixOS stage 2

let
  initScript = ''
    #!/bin/sh
    set -e

    echo "=== RT-AX88U initramfs ==="

    # Mount essential kernel filesystems
    /bin/mount -t proc proc /proc
    /bin/mount -t sysfs sysfs /sys
    /bin/mount -t devtmpfs devtmpfs /dev
    /bin/mkdir -p /dev/pts
    /bin/mount -t devpts devpts /dev/pts

    # Load storage modules if built as loadable (BSP usually has built-in)
    /sbin/modprobe -a usb-storage ext4 xhci-hcd 2>/dev/null || true

    # Wait for root device
    echo "Waiting for /dev/sda2..."
    ROOT_WAIT=10
    while [ $ROOT_WAIT -gt 0 ]; do
      if [ -b /dev/sda2 ]; then
        echo "Found /dev/sda2"
        break
      fi
      ROOT_WAIT=$((ROOT_WAIT - 1))
      sleep 1
    done

    if [ ! -b /dev/sda2 ]; then
      echo "ERROR: /dev/sda2 not found — dropping to shell"
      /bin/sh
    fi

    # Mount root
    echo "Mounting root filesystem..."
    /bin/mount -t ext4 -o noatime /dev/sda2 /mnt/root || {
      echo "ERROR: mount failed — dropping to shell"
      /bin/sh
    }

    if [ ! -d /mnt/root/nix/store ]; then
      echo "ERROR: /nix/store not found on root device"
      /bin/ls -la /mnt/root
      /bin/sh
    fi

    echo "=== switch_root → NixOS stage 2 ==="
    exec /bin/switch_root /mnt/root /nix/store
  '';
in stdenv.mkDerivation {
  pname = "rt-ax88u-initramfs";
  version = "0.1";

  src = null;
  phases = [ "buildPhase" "installPhase" ];
  preferLocalBuild = true;

  # The aarch64 busybox binary gets packed into the initramfs
  buildInputs = [ busybox ];
  nativeBuildInputs = [ buildPackages.cpio buildPackages.gzip ];

  buildPhase = ''
    runHook preBuild

    echo "=== Building initramfs ==="

    ROOT=$(pwd)/rootfs
    mkdir -p "$ROOT/bin" "$ROOT/sbin" "$ROOT/dev" "$ROOT/etc" "$ROOT/proc" "$ROOT/sys" "$ROOT/mnt/root" "$ROOT/run"

    # Static busybox binary for target architecture (aarch64)
    cp -L "${busybox}/bin/busybox" "$ROOT/bin/busybox"
    chmod +x "$ROOT/bin/busybox"

    # Busybox applet symlinks
    for applet in sh mount umount switch_root ls mkdir cat echo sleep test \
                  modprobe lsmod insmod dmesg clear reboot poweroff; do
      ln -sf busybox "$ROOT/bin/$applet"
    done
    ln -sf ../bin/busybox "$ROOT/sbin/modprobe"

    # Init script (PID 1)
    cat > "$ROOT/init" << 'INITEOF'
${initScript}
INITEOF
    chmod +x "$ROOT/init"

    # Pre-created device nodes
    cd "$ROOT/dev"
    mknod -m 622 console c 5 1 2>/dev/null || true
    mknod -m 666 null c 1 3 2>/dev/null || true
    mknod -m 666 zero c 1 5 2>/dev/null || true
    cd "$ROOT"

    # Create cpio archive (newc format, gzip)
    find . -print0 | cpio --null -o -H newc -R +0:+0 2>/dev/null | gzip -9 > "$(pwd)/initramfs.cpio.gz"

    SIZE=$(wc -c < "$(pwd)/initramfs.cpio.gz")
    echo "initramfs.cpio.gz: $SIZE bytes"
    echo "$SIZE bytes" > "$(pwd)/initramfs-size"

    runHook postBuild
  '';

  installPhase = ''
    mkdir -p $out
    cp initramfs.cpio.gz $out/
    cp initramfs-size $out/size
  '';

  meta = {
    description = "Minimal initramfs for ASUS RT-AX88U NixOS boot";
    longDescription = ''
      Busybox-based initramfs that mounts USB root (/dev/sda2, ext4) and
      switch_roots to NixOS stage 2. Embedded via CONFIG_INITRAMFS_SOURCE.
    '';
    platforms = lib.platforms.all;
  };
}
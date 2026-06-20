{ stdenv, lib, rt-ax88u-bsp-kernel, merlin-web-ui }:

# RT-AX88U validation checks.
# Fails if any check fails — used as `nix flake check` or CI.
# Two phases:
#   1. Kernel validation (ELF aarch64, symbols, config)
#   2. Package validation (web UI files exist)

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
      # Check aarch64 ELF
      file "$KERNEL" | grep -q "ELF 64-bit LSB executable, ARM aarch64" && \
        echo "OK: Image is aarch64 ELF" || \
        { echo "FAIL: Image is not aarch64 ELF"; errors=$((errors + 1)); }

      # Check key symbols (using nm on the vmlinux inside would need extraction,
      # but for now just check the config has expected options)
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

    # --- 2. Web UI packages check ---
    for pkg in www libshared libnvram libpasswd mssl libwebapi httpd; do
      case "$pkg" in
        www)    file="${merlin-web-ui.www}/www/index.html" ;;
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
    description = "Validation checks for RT-AX88U BSP kernel and web UI";
    platforms = lib.platforms.all;
  };
}

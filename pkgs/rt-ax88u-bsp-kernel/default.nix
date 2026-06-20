{ lib, stdenv, fetchFromGitHub, buildPackages, merlin-src }:

# BSP kernel for ASUS RT-AX88U (BCM4908)
#
# Builds the Broadcom BSP Linux 4.1.51 kernel from the Merlin source tree.
# The Merlin kernel tree has modified Makefiles that include external
# Broadcom drivers (bcmdrivers/) via relative path references.
# Prebuilt .o blobs from Broadcom's proprietary SDK are extracted from
# the Merlin source tree and injected into the bcmdrivers tree before
# the kernel build, following Merlin's platform.mak deployment rules.
#
# Cross-compiled for aarch64 from any build platform.

let
  pname = "linux";
  version = "4.1.51-rt-ax88u";

  src = merlin-src;

  # Merlin build constants (interpolated into phase strings)
  bcm_chip = "4908";
  prbm_ext = "_preb";
  hnd_router_ax = "y";

in stdenv.mkDerivation {
  inherit pname version src;

  # stay at repo root so relative paths work (../../bcmdrivers etc.)
  sourceRoot = ".";

  # native build tools (run on build machine/x86_64)
  nativeBuildInputs = with buildPackages; [
    bc bison flex openssl elfutils
  ];

  # kernel build environment
  ARCH = "arm64";
  CROSS_COMPILE = stdenv.cc.targetPrefix;
  KBUILD_BUILD_USER = "nix-builder";
  KBUILD_BUILD_HOST = "nixos";

  # disable warnings-as-errors for modern gcc
  NIX_CFLAGS_COMPILE = [ "-Wno-error" ];

  # Merlin build flags for BCM4908
  HND_ROUTER_AX = "y";
  BRCM_CHIP = "4908";
  CONFIG_BCM_CHIP_NUMBER = "4908";
  PRBM_EXT = "_preb";
  PREBUILT_EXTRAMOD = "1";

  # paths relative to source root (writable build directory, not store)
  # kernelRoot    = release/src-rt-5.02axhnd/kernel/linux-4.1
  # hndRoot       = release/src-rt-5.02axhnd
  # blobsDir      = release/src-rt-5.02axhnd/router-sysdep.rt-ax88u/hnd_extra/prebuilt
  # bcmdriversDir = release/src-rt-5.02axhnd/bcmdrivers

  preConfigure = ''
    echo "=== Deploying prebuilt blobs ==="

    HND_SRC="$PWD/release/src-rt-5.02axhnd"
    KERNEL_DIR="$HND_SRC/kernel/linux-4.1"
    BLOBS="$HND_SRC/router-sysdep.rt-ax88u/hnd_extra/prebuilt"

    cd "$HND_SRC"

    # create target directories
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/dhd/src/dhd/linux/prebuilt/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/dhd/src/shared/bcmwifi/include/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/wl/linux/prebuilt/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/components/avs/src/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/emf/linux/prebuilt/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/igs/linux/prebuilt/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/hnd/linux/prebuilt/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/wl/exe/prebuilt/
    mkdir -p bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/wl/sys/
    mkdir -p router-sysdep/hnd/prebuilt/
    mkdir -p router-sysdep/hnd_dhd/prebuilt/
    mkdir -p router-sysdep/hnd_emf/prebuilt/
    mkdir -p router-sysdep/hnd_igs/prebuilt/
    mkdir -p router-sysdep/hnd_wl/prebuilt/
    mkdir -p rdp/projects/WL4908/target/bdmf/
    mkdir -p rdp/projects/WL4908/target/rdpa/
    mkdir -p rdp/projects/WL4908/target/rdpa_gpl/
    mkdir -p rdp/projects/WL4908/target/rdpa_user/
    mkdir -p bcmdrivers/opensource/char/map/impl1

    # symlink for rdpa_gpl include
    ln -sf ../../../../../rdp/drivers/rdpa_gpl/include rdp/projects/WL4908/target/rdpa_gpl/include

    # === copy blobs per platform.mak logic ===

    # net/enet and net/wfd
    cp "$BLOBS/bcm_enet.o"    "bcmdrivers/opensource/net/enet/impl7/bcm_enet${prbm_ext}.o"
    cp "$BLOBS/wfd.o"         "bcmdrivers/opensource/net/wfd/impl1/wfd${prbm_ext}.o"

    # IVI map headers
    cp "$BLOBS/ivi_map.h"     "bcmdrivers/opensource/char/map/impl1/"
    cp "$BLOBS/ivi_config.h"  "bcmdrivers/opensource/char/map/impl1/"

    # RDP (WL4908 target)
    cp "$BLOBS/bdmf.o"        "rdp/projects/WL4908/target/bdmf/bdmf${prbm_ext}.o"
    cp "$BLOBS/rdpa.o"        "rdp/projects/WL4908/target/rdpa/rdpa${prbm_ext}.o"
    cp "$BLOBS/rdpa_gpl.o"    "rdp/projects/WL4908/target/rdpa_gpl/rdpa_gpl${prbm_ext}.o"
    cp "$BLOBS/rdpa_usr.o"    "rdp/projects/WL4908/target/rdpa_user/rdpa_usr${prbm_ext}.o"

    # shared driver blobs
    cp "$BLOBS/unimac_drv_impl1.o"  "shared/opensource/drv/unimac/"
    cp "$BLOBS/mac_drv_unimac.o"    "shared/opensource/drv/phys/"
    cp "$BLOBS/bcm_misc_hw_init_impl6.o" "shared/opensource/drivers/"

    # wireless executable blobs
    cp "$BLOBS/wl"               "bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/wl/exe/prebuilt/"
    cp "$BLOBS/wl_server_socket" "bcmdrivers/broadcom/net/wl/bcm9${bcm_chip}/main/src/wl/exe/prebuilt/"

    # broadcom char drivers
    cp "$BLOBS/bcm_bpm.o"     "bcmdrivers/broadcom/char/bpm/impl1/bcm_bpm${prbm_ext}.o"
    cp "$BLOBS/chipinfo.o"    "bcmdrivers/broadcom/char/chipinfo/impl1/chipinfo${prbm_ext}.o"
    cp "$BLOBS/cmdlist.o"     "bcmdrivers/broadcom/char/cmdlist/impl1/cmdlist${prbm_ext}.o"
    cp "$BLOBS/pktflow.o"     "bcmdrivers/broadcom/char/pktflow/impl1/pktflow${prbm_ext}.o"
    cp "$BLOBS/pktrunner.o"   "bcmdrivers/broadcom/char/pktrunner/impl2/pktrunner${prbm_ext}.o"
    cp "$BLOBS/pwrmngtd.o"    "bcmdrivers/broadcom/char/pwrmngt/impl1/pwrmngtd${prbm_ext}.o"
    cp "$BLOBS/nciTMSkmod.o"  "bcmdrivers/broadcom/char/tms/impl1/nciTMSkmod${prbm_ext}.o"
    cp "$BLOBS/bcmvlan.o"     "bcmdrivers/broadcom/char/vlan/impl1/bcmvlan${prbm_ext}.o"
    cp "$BLOBS/wlcsm.o"       "bcmdrivers/broadcom/char/wlcsm_ext/impl1/wlcsm${prbm_ext}.o"

    # board support
    cp "$BLOBS/bcm63xx_flash.o"  "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/bcm63xx_gpio.o"   "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/bcm63xx_led.o"    "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board.o"          "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/compat_board.o"   "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/pushbutton.o"     "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/spidevices.o"     "bcmdrivers/opensource/char/board/bcm963xx/impl1/"

    # platform blobs
    cp "$BLOBS/rdp_fpm.o"        "bcmdrivers/opensource/char/fpm/impl1/rdp_fpm${prbm_ext}.o"
    cp "$BLOBS/i2c_bcm6xxx.o"    "bcmdrivers/opensource/char/i2c/busses/impl1/"
    cp "$BLOBS/bcmmcast.o"       "bcmdrivers/opensource/char/mcast/impl1/bcmmcast${prbm_ext}.o"
    cp "$BLOBS/bcmpdc.o"         "bcmdrivers/opensource/char/pdc/impl1/bcmpdc${prbm_ext}.o"

    # arm64 platform setup
    cp "$BLOBS/bcm_arm64_setup.o"    "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/bcm_arm_cpuidle.o"    "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/bcm_arm_irq.o"        "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/bcm_dt.o"             "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/bcm_extirq.o"         "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/bcm_i2c.o"            "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/bcm_legacy_io_map.o"  "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/bcm_thermal.o"        "bcmdrivers/opensource/char/plat-bcm/impl1/bcm_thermal${prbm_ext}.o"
    cp "$BLOBS/bcm_usb.o"            "bcmdrivers/opensource/char/plat-bcm/impl1/bcm_usb${prbm_ext}.o"
    cp "$BLOBS/blxargs.o"            "bcmdrivers/opensource/char/plat-bcm/impl1/"
    cp "$BLOBS/setup.o"              "bcmdrivers/opensource/char/plat-bcm/impl1/"

    # RDPA drivers
    cp "$BLOBS/rdpa_cmd.o"      "bcmdrivers/opensource/char/rdpa_drv/impl1/rdpa_cmd${prbm_ext}.o"
    cp "$BLOBS/rdpa_gpl_ext.o"  "bcmdrivers/opensource/char/rdpa_gpl_ext/impl1/rdpa_gpl_ext${prbm_ext}.o"
    cp "$BLOBS/rdpa_mw.o"       "bcmdrivers/opensource/char/rdpa_mw/impl1/rdpa_mw${prbm_ext}.o"

    # serial and crypto
    cp "$BLOBS/bcm63xx_cons.o"  "bcmdrivers/opensource/char/serial/impl1/bcm63xx_cons${prbm_ext}.o"
    cp "$BLOBS/bcmspu.o"        "bcmdrivers/opensource/char/spudd/impl4/bcmspu${prbm_ext}.o"

    # PMC (power management)
    cp "$BLOBS/clk_rst.o"       "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_drv.o"       "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_fpm.o"       "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_pcie.o"      "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_pcm.o"       "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_rdp.o"       "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_sata.o"      "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_spu.o"       "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_switch.o"    "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_sysfs.o"     "shared/opensource/pmc/impl1/"
    cp "$BLOBS/pmc_usb.o"       "shared/opensource/pmc/impl1/"

    # HND router-sysdep (HND_ROUTER_AX=y)
    cp "$BLOBS/hnd.o"           "router-sysdep/hnd/prebuilt/"
    cp "$BLOBS/dhd.o"           "router-sysdep/hnd_dhd/prebuilt/"
    cp "$BLOBS/emf.o"           "router-sysdep/hnd_emf/prebuilt/"
    cp "$BLOBS/igs.o"           "router-sysdep/hnd_igs/prebuilt/"
    cp "$BLOBS/wl.o"            "router-sysdep/hnd_wl/prebuilt/wl_apsta.o"
    cp "$BLOBS/wl.o"            "router-sysdep/hnd_wl/prebuilt/"
    cp "$BLOBS/bcm_pcie_hcd.o"  "bcmdrivers/opensource/bus/pci/host/impl1/bcm_pcie_hcd${prbm_ext}.o"

    # HND board support
    cp "$BLOBS/board_button.o"  "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board_dg.o"      "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board_image.o"   "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board_ioctl.o"   "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board_proc.o"    "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board_util.o"    "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board_wd.o"      "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/board_wl.o"      "bcmdrivers/opensource/char/board/bcm963xx/impl1/"
    cp "$BLOBS/bcmsfp_i2c.o"    "bcmdrivers/opensource/char/i2c/chips/impl1/"
    cp "$BLOBS/opticaldet.o"    "bcmdrivers/opensource/char/opticaldet/impl1/opticaldet${prbm_ext}.o"
    cp "$BLOBS/detect_opt.o"    "bcmdrivers/opensource/char/wantypedet/impl1/detect_opt${prbm_ext}.o"

    echo "=== Blob deployment complete ==="
    echo "Checking key blobs:"
    ls -la bcmdrivers/opensource/net/enet/impl7/bcm_enet${prbm_ext}.o
    ls -la bcmdrivers/opensource/net/wfd/impl1/wfd${prbm_ext}.o
    ls -la rdp/projects/WL4908/target/bdmf/bdmf${prbm_ext}.o
    ls -la shared/opensource/drv/unimac/unimac_drv_impl1.o
    ls -la bcmdrivers/broadcom/char/bpm/impl1/bcm_bpm${prbm_ext}.o
    echo "Total blobs deployed: $(find "$HND_SRC" -name '*_preb.o' | wc -l)"
  '';

  configurePhase = ''
    echo "=== Configuring kernel ==="
    cd "$PWD/release/src-rt-5.02axhnd/kernel/linux-4.1"

    # apply Merlin's base config
    cp config_base.6a .config

    # enable systemd requirements
    cat >> .config << 'KCONFIG'
CONFIG_CGROUPS=y
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y
CONFIG_FHANDLE=y
CONFIG_NAMESPACES=y
CONFIG_NET_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_POSIX_MQUEUE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_MEMCG=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_FANOTIFY=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
KCONFIG

    # finalize config
    make olddefconfig ARCH=$ARCH
    echo "--- systemd configs ---"
    grep 'CONFIG_CGROUPS\|CONFIG_FHANDLE\|CONFIG_NAMESPACES\|CONFIG_SECCOMP' .config | head -10
    echo "---"
  '';

  buildPhase = ''
    echo "=== Building kernel Image ==="
    cd "$PWD/release/src-rt-5.02axhnd/kernel/linux-4.1"

    make -j$NIX_BUILD_CORES \
      ARCH=$ARCH \
      CROSS_COMPILE=$CROSS_COMPILE \
      Image
  '';

  installPhase = ''
    echo "=== Installing kernel ==="
    cd "$PWD/release/src-rt-5.02axhnd/kernel/linux-4.1"

    # kernel image
    mkdir -p $out
    cp arch/arm64/boot/Image $out/Image
    cp .config $out/config
    echo "${version}" > $out/kernel.release

    # Try to build modules (may partially fail — BSP may not support modules)
    make -j$NIX_BUILD_CORES \
      ARCH=$ARCH \
      CROSS_COMPILE=$CROSS_COMPILE \
      modules 2>&1 || echo "modules build did not fully succeed (expected)"

    make -j$NIX_BUILD_CORES \
      ARCH=$ARCH \
      CROSS_COMPILE=$CROSS_COMPILE \
      INSTALL_MOD_PATH=$out \
      modules_install 2>&1 || echo "modules_install did not fully succeed (expected)"

    echo "=== Build complete ==="
    file $out/Image
    ls -lh $out/Image
  '';

  meta = {
    description = "Broadcom BSP Linux 4.1.51 kernel for ASUS RT-AX88U (BCM4908)";
    homepage = "https://github.com/RMerl/asuswrt-merlin.ng";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ ];
    platforms = [ "aarch64-linux" ];
  };
}

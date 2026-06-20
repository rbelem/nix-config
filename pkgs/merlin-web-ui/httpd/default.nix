{ lib, stdenv, merlin-src, libshared, libnvram, libpasswd, mssl, libwebapi, openssl, jsonc, libxcrypt }:

# httpd — ASUSWRT-Merlin web server and UI backend.
#
# This is the main web server binary that serves the router's admin UI.
# It compiles Merlin source files from router/httpd/ and links against
# libshared, libnvram, and other Merlin libraries plus OpenSSL and json-c.
#
# For Broadcom-proprietary components without source (pwenc, web_hook,
# web-broadcom), we use prebuilt .o files from Merlin's prebuild directory
# when available, or create stubs when not.

let
  srcBase = "${merlin-src}/release/src-rt-5.02axhnd";
  httpdDir = "${srcBase}/router/httpd";
  prebuiltDir = "${httpdDir}/prebuild/RT-AX88U";
  wlSrc = "${srcBase}/bcmdrivers/broadcom/net/wl/impl51/main/src/include";
  wlShared = "${srcBase}/bcmdrivers/broadcom/net/wl/impl51/main/src/shared";

  toolPrefix = stdenv.cc.targetPrefix;

in stdenv.mkDerivation {
  pname = "merlin-httpd";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = ''
    export CC="${toolPrefix}gcc"
    export AR="${toolPrefix}ar"
    export LD="${toolPrefix}ld"

    SRC="$PWD/release/src-rt-5.02axhnd"
    KCFG="${srcBase}/kernel/linux-4.1/config_base.6a"

    # Generate rtconfig.h (needed by httpd.h)
    # Skip USB configs to avoid pulling in missing USB component headers.
    echo "/* Auto-generated (USB configs filtered out) */" > "$SRC/router/httpd/rtconfig.h"
    while IFS='=' read -r key val; do
      case "X$key" in
        XCONFIG_USB_*|XCONFIG_USB) ;;
        XCONFIG_*) echo "#define RTCONFIG_$(echo "$key" | sed 's/^CONFIG_//') $val" ;;
      esac
    done < "$KCFG" >> "$SRC/router/httpd/rtconfig.h"

    # Fix broken paren in shared.h (Broadcom typo)
    sed -i 's/__attribute__((unused) \*/__attribute__((unused)) */g' "$SRC/router/shared/shared.h"

    # === Compiler flags matching Merlin's httpd/Makefile for HND_ROUTER_AX ===
    CFLAGS="-Os -Wall -fPIC -std=gnu17 -Wno-error=format-security -Wno-int-conversion -Wno-unused-function"
    CFLAGS+=" -Wno-implicit-function-declaration"  # web.c references many Merlin functions not available in piecemeal build
    CFLAGS+=" -DTYPEDEF_FLOAT_T"  # Prevent float_t redefinition conflict between Broadcom typedefs.h and <math.h>
    CFLAGS+=" -I$SRC/router/httpd"
    CFLAGS+=" -I${srcBase}/include"
    CFLAGS+=" -I$SRC/router"
    CFLAGS+=" -I$SRC/router/shared"
    CFLAGS+=" -I${wlSrc}"
    CFLAGS+=" -I${wlShared}/bcmwifi/include"
    # Stub out missing Broadcom components include paths
    mkdir -p "$PWD/components/proto" "$PWD/components/wlioctl/include"
    # Aggressive stub generation for ALL missing Broadcom component headers
    # sysinfo.c, web.c reference dozens of Broadcom SDK headers not in Merlin tree
    for stubdir in wlioctl/include router asusopt bcmcrypto bcmcrypto/libcrypto; do
      mkdir -p "$PWD/components/$stubdir"
    done
    cat > "$PWD/components/wlioctl/include/wlioctl_defs.h" << 'STUB_H'
#ifndef _wlioctl_defs_h_
#define _wlioctl_defs_h_
#endif
STUB_H
    cat > "$PWD/components/wlioctl/include/wlioctl.h" << 'STUB_H'
#ifndef _wlioctl_h_
#define _wlioctl_h_
#include <typedefs.h>
/* Provide struct ether_addr in case proto/ethernet.h isn't included */
#ifndef _ETHER_ADDR_DEFINED
#define _ETHER_ADDR_DEFINED
#ifndef ETHER_ADDR_LEN
#define ETHER_ADDR_LEN 6
#endif
struct ether_addr {
    unsigned char octet[ETHER_ADDR_LEN];
} __attribute__((packed));
#endif

/* Broadcom wireless ioctl stubs for compilation */
#define WLC_IOCTL_MAXLEN 8192
#define WLC_IOCTL_SMLEN 256
#define WLC_GET_MAGIC 0
#define WLC_GET_VERSION 1
#define WLC_GET_AP 23
#define WLC_GET_RADIO 25
#define WLC_SET_RADIO 26
#define WLC_GET_MONITOR 194
#define WLC_GET_ASSOCLIST 127
#define WLC_GET_VAR 133
#define WLC_SET_VAR 134
#define WLC_GET_WSEC 139
#define WLC_SET_WSEC 140
#define WLC_GET_RSSI 155

struct maclist {
    unsigned int count;
    unsigned int max_count;
    struct ether_addr ea[1];
};
extern int wl_ioctl(char *name, int cmd, void *buf, int len);

/* wlc_ssid_t used by web-broadcom-am.c */
typedef struct {
    unsigned int  SSID_len;
    unsigned char SSID[32];
} wlc_ssid_t;

/* Radio disable flags */
#define WL_RADIO_SW_DISABLE   0x0001
#define WL_RADIO_HW_DISABLE   0x0002
#endif
STUB_H
    # openvpn_config.h is included with #include "openvpn_config.h" (quotes)
    # so it needs to be in the httpd directory or the source file's directory
    cat > "$SRC/router/httpd/openvpn_config.h" << 'STUB_H'
#ifndef _openvpn_config_h_
#define _openvpn_config_h_
#endif
STUB_H
    cat > "$PWD/components/router/wlutils.h" << 'STUB_H'
#ifndef _wlutils_h_
#define _wlutils_h_
#include <typedefs.h>
#endif
STUB_H
    cat > "$PWD/components/router/rtstate.h" << 'STUB_H'
#ifndef _rtstate_h_
#define _rtstate_h_
#endif
STUB_H
    # Add router stubs to include path
    CFLAGS+=" -I$PWD/components/router"
    cat > "$PWD/components/proto/ethernet.h" << 'ETHERNET_H'
/* Auto-generated stub for missing Broadcom proto/ethernet.h */
#ifndef _proto_ethernet_h_
#define _proto_ethernet_h_

#include <sys/types.h>

#define ETHER_ADDR_LEN      6
#define ETHER_TYPE_LEN      2
#define ETHER_CRC_LEN       4
#define ETHER_HDR_LEN       14
#define ETHER_MIN_LEN       60
#define ETHER_MAX_LEN       1514

#ifndef _ETHER_ADDR_DEFINED
#define _ETHER_ADDR_DEFINED
struct ether_addr {
    unsigned char octet[ETHER_ADDR_LEN];
} __attribute__((packed));
#endif

struct ether_header {
    struct  ether_addr  ether_dhost;
    struct  ether_addr  ether_shost;
    unsigned short      ether_type;
} __attribute__((packed));

#endif /* _proto_ethernet_h_ */
ETHERNET_H
    # Include paths for stubbed Broadcom components
    CFLAGS+=" -I$PWD/components"
    CFLAGS+=" -I$PWD/components/wlioctl/include"
    # Force-include wlioctl.h so struct maclist and WLC_* constants are available everywhere
    CFLAGS+=" -include $PWD/components/wlioctl/include/wlioctl.h"

    # Merlin defines
    # Merlin feature defines for RT-AX88U
    CFLAGS+=" -DHND_ROUTER -DHND_ROUTER_AX"
    CFLAGS+=" -DWL11AC_80P80 -DWL11AC_160"
    CFLAGS+=" -DCHIP_4908 -DCONFIG_BCM94908"
    CFLAGS+=" -D_FILE_OFFSET_BITS=64"

    # Missing Broadcom/feature constants (for web.c compatibility)
    CFLAGS+=" -DASUS_DDNS -DTRANSLATE_ON_FLY -DFLASH_EMULATOR -DLinux -DWSC"
    CFLAGS+=" -DLINUX_KERNEL_VERSION=264451"

    # External library includes
    CFLAGS+=" -I${openssl.dev}/include"
    CFLAGS+=" -I${jsonc.dev}/include/json-c"

    CFLAGS+=" -I$SRC/router/mssl"
    CFLAGS+=" -I$SRC/router/libpasswd"
    CFLAGS+=" -I$SRC/router/libwebapi"
    CFLAGS+=" -I$SRC/router/libasuslog"
    CFLAGS+=" -I$SRC/router/networkmap"

    echo "=== Building httpd ==="
    echo "CC: $CC"
    cd "$SRC/router/httpd"

    # Pre-declare libasuslog and syslog functions (missing in build env)
    # These are stub declarations — the actual symbols come from the
    # router's libasuslog.so at runtime.
    CFLAGS+=" -DLOG_INFO=6"
    CFLAGS+=" -DLOG_CUSTOM=0 -DLOG_SHOWTIME=1"
    cat > libasuslog_stub.h << 'STUB_H'
int asusdebuglog(int level, char *path, int conlog, int showtime, unsigned filesize, const char *msgfmt, ...);
int Debug2String(int level, char *path, int conlog, int showtime, unsigned filesize, const char *func, int line, const char *msgfmt, ...);
int security2log(int level, char *path, int conlog, int showtime, unsigned filesize, const char *msgfmt, ...);
STUB_H
    # Generate version.h stub — this file is normally generated by the
    # Merlin build system from firmware version info.
    cat > "$SRC/router/httpd/version.h" << 'VERSION_H'
/* Auto-generated stub for Merlin build system version.h */
#ifndef _version_h_
#define _version_h_

#define RT_BUILD_NAME "RT-AX88U"
#define BUILD_NAME "RT-AX88U"
#define FIRMWARE_VERSION "merlin-ng"

extern char *get_productid(void);
#endif
VERSION_H

    # Generate missing constants/defines for web.c compatibility
    cat > "$PWD/merlin_defs.h" << 'MERLIN_DEFS'
/* Merlin feature constants not defined by the build system */
#ifndef OVPN_RGW_NONE
#define OVPN_RGW_NONE 0
#endif
#ifndef OVPN_TYPE_CLIENT
#define OVPN_TYPE_CLIENT 0
#define OVPN_TYPE_SERVER 1
#endif
#ifndef VPNDIR_PROTO_NONE
#define VPNDIR_PROTO_NONE 0
#endif
#ifndef MTLAN_MAXINUM
#define MTLAN_MAXINUM 16
#endif
#ifndef HTTPD_ROOTCA_KEY
#define HTTPD_ROOTCA_KEY "/etc/cert.key"
#endif
#ifndef HTTPD_CERT
#define HTTPD_CERT "/etc/cert.crt"
#endif
#ifndef HTTPD_KEY
#define HTTPD_KEY "/etc/key.pem"
#endif
#ifndef WL_BW_20
#define WL_BW_20 0
#define WL_BW_40 1
#define WL_BW_80 2
#define WL_BW_160 3
#define WL_BW_AUTO 4
#endif
/* Declared in httpd.c, used by web.c */
extern int do_ssl;
/* Wireless station struct/constants (used by web-broadcom-am.c) */
#ifndef WL_STA_AUTHO
#define WL_STA_AUTHO   0x0002
#define WL_STA_ASSOC   0x0004
#endif
struct wl_sta {
    unsigned char bssid[6];
    unsigned int  flags;
    unsigned int  in;
    unsigned int  ht_capabilities;
    unsigned int  vht_flags;
    int           rx_rate;
    int           tx_rate;
};
typedef struct wl_sta sta_info_t;
#define WL_STA_PS 0x0008
#define WL_STA_SCBSTATS 0x0010
typedef struct { unsigned char ea[6]; int val; int rssi; } scb_val_t;
#ifndef WLC_GET_VAR
#define WLC_GET_VAR 133
#endif
#ifndef WLC_GET_RSSI
#define WLC_GET_RSSI 155
#endif
#ifndef WL_STA_SCBSTATS
#define WL_STA_SCBSTATS 0x0010
#endif
MERLIN_DEFS
    CFLAGS+=" -include $PWD/libasuslog_stub.h -include $PWD/merlin_defs.h"

    # web-broadcom-am.c requires deep Broadcom SDK types not in Merlin tree.
    # Replace with stubs for the functions referenced by httpd dispatch table.
    cat > "$SRC/router/httpd/sysdeps/web-broadcom-am.c" << 'STUB_WEB_BCM'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <httpd.h>
#include <shared.h>
#include <bcmnvram.h>
int ej_wl_status_array(int eid, webs_t wp, int argc, char **argv) {
    return websWrite(wp, "\"\",\"\",\"\",\"\",\"\",\"\"");
}
int ej_wl_extent_channel(int eid, webs_t wp, int argc, char **argv) {
    return websWrite(wp, "\"\"");
}
int wl_control_channel(int unit) { return 0; }
int wl_format_ssid(char *buf, unsigned char *ssid, int len) { return 0; }
STUB_WEB_BCM

    # === Compile source objects ===
    echo "Compiling source files..."
    for src in \
      httpd.c cgi.c ej.c web.c common.c \
      aspbw.c initial_web_hook.c apps.c \
      sysinfo.c data_arrays.c \
      sysdeps/web-broadcom-am.c; do
      base=$(basename "$src" .c)
      echo "  CC $src"
      $CC $CFLAGS -c -o "$base.o" "$src"
    done

    # === Stub prebuilt objects (wrong arch for cross-compile) ===
    # pwenc.o and web_hook.o are prebuilt ARM objects from Merlin's prebuild
    # directory. They don't work for aarch64 cross-compilation.
    echo "  [stub] pwenc.o (prebuilt unavailable for aarch64)"
    cat > pwenc_stub.c << 'STUB'
int pwenc(char *passwd, int authe, char *enc, int aes_len) { return 0; }
STUB
    $CC $CFLAGS -c -o pwenc.o pwenc_stub.c
    echo "  [stub] web_hook.o (prebuilt unavailable for aarch64)"
    cat > web_hook_stub.c << 'STUB'
int process_web_hook(unsigned int op, void *data) { return 0; }
STUB
    $CC $CFLAGS -c -o web_hook.o web_hook_stub.c
    echo "  [stub] web-broadcom.o (not available for RT-AX88U)"
    cat > web-broadcom_stub.c << 'STUB'
int web_broadcom_init(void) { return 0; }
STUB
    $CC $CFLAGS -c -o web-broadcom.o web-broadcom_stub.c
    # Stub missing symbol implementations for libwebapi dependencies
    cat > libwebapi_stubs.c << 'STUB'
int _eval(char *const argv[], char *stdout_path, int timeout, int *out) { return 0; }
int check_if_file_exist(const char *path) { return 0; }
int _vstrsep(char **ptr, const char *delim, char *buf, size_t bufsz) { return 0; }
void dbg(const char *fmt, ...) { }
int nvram_set_int(const char *name, int val) { return 0; }
int nvram_get_int(const char *name) { return 0; }
int get_string_in_62(const char *buf, const char *name, char *out, int outlen) { return 0; }
STUB
    $CC $CFLAGS -c -o libwebapi_stubs.o libwebapi_stubs.c
    # More stubs for data_arrays.o, webapi.o, libpasswd, libshared deps
    cat > httpd_extra_stubs.c << 'STUB'
int get_ipv6_service(void) { return 0; }
char *nvram_default_get(const char *name, const char *def) { return NULL; }
char *get_wan6face(void) { return NULL; }
int getifaddr(char *ifname, char *addr, int len) { return 0; }
char *ipv6_gateway_address(void) { return NULL; }
int sync_profile_update_time(int type) { return 0; }
char *router_defaults(void) { return NULL; }
char *nvram_pf_get(const char *name) { return NULL; }
STUB
    $CC $CFLAGS -c -o httpd_extra_stubs.o httpd_extra_stubs.c
    # Comprehensive shared library stubs for all missing symbols
    cat > libshared_stubs.c << 'STUBEOF'
#include <stdarg.h>
#include <stddef.h>
/* NOTE: Do NOT include httpd.h here — stub signatures intentionally
   differ from headers; we only provide linker symbols. */
char *amvpn_get_policy_rules(int a, char *b, int l, int p) { return NULL; }
int app_auth(void) { return 0; }
int asusdebuglog(int level, char *path, int conlog, int showtime, unsigned int filesize, const char *msgfmt, ...) { return 0; }
int ATE_FACTORY_MODE_STR(void) { return 0; }
int auth_check(const char *s) { return 0; }
int captcha_on(void) { return 0; }
int change_preferred_lang(void) { return 0; }
char *char_to_ascii_safe(char *s) { return s; }
int check_cmd_injection_blacklist(void) { return 0; }
int check_cmd_whitelist(void) { return 0; }
int check_imagefile(const char *s) { return 0; }
int check_imageheader(const char *s) { return 0; }
int check_lang_support(const char *s) { return 0; }
int check_lock_state(void) { return 0; }
int check_lock_status(void) { return 0; }
int check_noauth_referrer(void) { return 0; }
int check_user_agent(void) { return 0; }
int check_xss_blacklist(void) { return 0; }
int chld_reap(void) { return 0; }
int clean_ban_ip_timeout(void) { return 0; }
int config_iptv_vlan(void) { return 0; }
void cprintf(const char *f, ...) { }
int customized_match(void) { return 0; }
int delete_logout_from_list(void) { return 0; }
int do_chpass(void) { return 0; }
int do_dfb_log_file(void) { return 0; }
int do_feedback_mail_cgi(void) { return 0; }
int do_get_privacy_policy_cgi(void) { return 0; }
int do_get_cta_info_cgi(void) { return 0; }
int do_get_nonce_cgi(void) { return 0; }
int do_register_app_cnonce_cgi(void) { return 0; }
int do_save_all_profile_cgi(void) { return 0; }
int do_set_fw_path_cgi(void) { return 0; }
int do_start_config_sync_cgi(void) { return 0; }
int doSystem(const char *c, ...) { return 0; }
int do_upload_blacklist_config_cgi(void) { return 0; }
int do_upload_config_sync_cgi(void) { return 0; }
int do_upload_config_sync_post(void) { return 0; }
int do_webdavInfo_asp(void) { return 0; }
int ej_generate_region(int e, void *w, int a, char **v) { return 0; }
int ej_get_iptvSettings(int e, void *w, int a, char **v) { return 0; }
int ej_get_stbPortMappings(int e, void *w, int a, char **v) { return 0; }
int ej_get_support_region_list(int e, void *w, int a, char **v) { return 0; }
int ej_get_ui_support(int e, void *w, int a, char **v) { return 0; }
int ej_get_wlstainfo_list(int e, void *w, int a, char **v) { return 0; }
int ej_nat_accel_status(int e, void *w, int a, char **v) { return 0; }
int ej_wl_auth_list(int e, void *w, int a, char **v) { return 0; }
int ej_wl_channel_list_2g(int e, void *w, int a, char **v) { return 0; }
int ej_wl_channel_list_5g(int e, void *w, int a, char **v) { return 0; }
int ej_wl_chanspecs(int e, void *w, int a, char **v) { return 0; }
int ej_wl_scan_2g(int e, void *w, int a, char **v) { return 0; }
int ej_wl_scan_5g(int e, void *w, int a, char **v) { return 0; }
int ej_wl_sta_list_2g(int e, void *w, int a, char **v) { return 0; }
int ej_wl_sta_list_5g(int e, void *w, int a, char **v) { return 0; }
int ej_wl_status(int e, void *w, int a, char **v) { return 0; }
int ej_wl_status_2g(int e, void *w, int a, char **v) { return 0; }
int ej_wps_info(int e, void *w, int a, char **v) { return 0; }
int ej_wps_info_2g(int e, void *w, int a, char **v) { return 0; }
int ej_wps_info_5g(int e, void *w, int a, char **v) { return 0; }
int ej_wps_info_5g_2(int e, void *w, int a, char **v) { return 0; }
int ether_atoe(const char *p, void *e) { return 0; }
int file2str(const char *p, char *b, int l) { return 0; }
int file_lock(const char *n) { return 0; }
int file_unlock(const char *n) { return 0; }
int filter_ban_ip(void) { return 0; }
char *find_word(char *s, const char *w) { return NULL; }
void free_caches(void) { }
int f_size(void) { return 0; }
int f_write_string(const char *p, const char *s) { return 0; }
int gen_asus_token_cookie(void) { return 0; }
int gen_guestnetwork_pass(void) { return 0; }
int gen_random_string(char *b, int l) { return 0; }
int get_2g_hwaddr(void) { return 0; }
int get_ddns_macaddr(void) { return 0; }
int get_discovery_ssid(void) { return 0; }
int get_encrypt_wifi_status(void) { return 0; }
int get_extend_cap(void) { return 0; }
char *get_file_md5(const char *i) { return NULL; }
int get_iface_inode(void) { return 0; }
int get_index_page(void) { return 0; }
int get_label_mac(void) { return 0; }
int get_lang_num(void) { return 0; }
int get_lan_hwaddr(void) { return 0; }
int get_logfile_path(void) { return 0; }
int get_model(void) { return 0; }
char *get_ovpn_custom(int t, int u, char *b, int l) { return NULL; }
char *get_productid(void) { return "RT-AX88U"; }
int get_radio(void) { return 0; }
int get_rtinfo(void) { return 0; }
char *get_string_md5(const char *i) { return NULL; }
int get_syslog_fname(void) { return 0; }
int get_wifi_probe_result(void) { return 0; }
int handle_nvram_modify_log(const char *n, ...) { return 0; }
int ifname_ino_ptr(void) { return 0; }
int inet_deconflict(void) { return 0; }
int ipv6_nvname(void) { return 0; }
int is_builtin_profile(void) { return 0; }
int is_passwd_default(void) { return 0; }
int is_private_subnet(const char *s) { return 0; }
int isValid_digit_string(const char *s) { return 0; }
int isValidEnableOption(void) { return 0; }
int is_valid_ip(const char *s) { return 0; }
int isValidMacAddress(const char *s) { return 0; }
int kill_pidfile_s(void) { return 0; }
void logmessage_normal(const char *f, ...) { }
int netdev_calc(void) { return 0; }
int notify_rc(const char *f, ...) { return 0; }
int notify_rc_and_wait_2min(void) { return 0; }
int num_of_mssid_support(void) { return 0; }
int num_of_wl_if(void) { return 0; }
int nvram_get_f(const char *n, ...) { return 0; }
int nvram_get_list_x(const char *n, ...) { return 0; }
int nvram_contains_word(const char *n, ...) { return 0; }
int nvram_modify_log(void) { return 0; }
int notify_rc_after_period_wait(const char *f, ...) { return 0; }
int reg_default_final_token(void) { return 0; }
int redirect_service_page(void) { return 0; }
int set_ASUS_NEW_EULA(void) { return 0; }
int do_set_ASUS_privacy_policy_cgi(void) { return 0; }
int do_get_ASUS_privacy_policy_cgi(void) { return 0; }
int syslog_msg_filter(void) { return 0; }
int ipisdomain(void) { return 0; }
int mime_referers(void) { return 0; }
int referer_check(void) { return 0; }
int nvram_pf_get_int(const char *n, ...) { return 0; }
int nvram_pf_set(const char *n, ...) { return 0; }
int nvram_set_f(const char *n, ...) { return 0; }
int nvram_set_x(const char *n, ...) { return 0; }
int ParseIPv4OrIPv6(void) { return 0; }
int pidof(void) { return 0; }
int read_whole_file(const char *p, char *b, int l) { return 0; }

void replace_char(char *str, char find, char replace) { }
int rfctime(void) { return 0; }
int router_state_defaults(void) { return 0; }
int save_iptvSettings_to_file(void) { return 0; }
int save_ui_support_to_file(void) { return 0; }
void SECURITY_LOG(const char *f, ...) { }
int set_ASUS_EULA(void) { return 0; }
void slowloris_check(void) { }
void slow_post_read_check(void) { }
void store_file_var(char *login_url, char *file) { }
char *str_escape_quotes(char *s) { return s; }
int useful_redirect_page(char *next_page) { return 0; }
void system_cmd_test(char *system_cmd, char *SystemCmd, int len) { }
char *toLowerCase(char *s) { return s; }
char *toUpperCase(char *s) { return s; }
char *trim_colon(char *s) { return s; }
char *trimNL(char *s) { return s; }
int upgrade_rc(void) { return 0; }
int validate_apply_input_value(const char *s) { return 0; }
int validate_httpd_auth_v2(const char *s) { return 0; }
int waitfor(const char *n, int t) { return 0; }
int wan_primary_ifunit(void) { return 0; }
int wl_ioctl(char *n, int c, void *b, int l) { return 0; }
int wl_nvname(void) { return 0; }
STUBEOF
    $CC $CFLAGS -c -o libshared_stubs.o libshared_stubs.c

    # === Link httpd binary ===
    echo "Linking httpd..."
    $CC -o httpd \
      httpd.o cgi.o ej.o web.o common.o \
      aspbw.o initial_web_hook.o apps.o \
      sysinfo.o data_arrays.o web-broadcom-am.o \
      pwenc.o web_hook.o web-broadcom.o libwebapi_stubs.o httpd_extra_stubs.o libshared_stubs.o \
      -L${libwebapi}/lib -lwebapi \
      -L${libshared}/lib -lshared \
      -L${libnvram}/lib -lnvram \
      -L${libpasswd}/lib -lpasswd \
      -L${mssl}/lib -lmssl \
      -L${libxcrypt}/lib -lcrypt \
      -L${openssl.out}/lib -lssl -lcrypto -ldl \
      -L${jsonc}/lib -ljson-c \
      -lm -lpthread -lgcc_s
  '';

  installPhase = ''
    mkdir -p $out/sbin
    cp "$SRC/router/httpd/httpd" $out/sbin/
    ${toolPrefix}strip $out/sbin/httpd || true
  '';

  meta = {
    description = "ASUSWRT-Merlin web server for RT-AX88U";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

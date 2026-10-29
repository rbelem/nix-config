# Samsung Galaxy Book3 360 | NP730QFG-KF1BR
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

let
  # Same symlink-farm nixpkgs builds in
  # modules/services/display-managers/default.nix from sessionPackages,
  # minus hyprland-uwsm.desktop (the hyprland package ships it
  # unconditionally, and list options cannot subtract a module's entry).
  desktopsWithoutUwsm =
    pkgs.runCommand "desktops-without-uwsm"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      (
        ''
          mkdir -p $out/share/{xsessions,wayland-sessions}
        ''
        + lib.concatMapStringsSep "\n" (pkg: ''
          if test -d ${pkg}/share/xsessions; then
            ${pkgs.buildPackages.lndir}/bin/lndir ${pkg}/share/xsessions $out/share/xsessions || true
          fi
          if test -d ${pkg}/share/wayland-sessions; then
            ${pkgs.buildPackages.lndir}/bin/lndir ${pkg}/share/wayland-sessions $out/share/wayland-sessions || true
          fi
        '') config.services.displayManager.sessionPackages
        + ''
          rm -f $out/share/wayland-sessions/hyprland-uwsm.desktop \
            $out/share/wayland-sessions/hyprland.desktop
        ''
      );
in
{

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.hardware.nixosModules.common-pc-laptop-ssd

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./attic.nix
    ./bluetooth.nix
    ./bootloader.nix
    ./display.nix
    ./forticlient.nix
    ./id.nix
    ./keyboard.nix
    ./networking.nix
    ./nvme.nix
    ./plugins.nix
    ./sensors.nix
    ./shuttle-pod-tools.nix
    ./sound.nix
    ./touch.nix

    ../../common

    ../../users/rodrigo

    ../../desktop/android.nix
    ../../desktop/fonts.nix
    ../../desktop/kde.nix
    ../../desktop/monitor-brightness.nix
    ../../desktop/touch-scroll.nix
    #../../desktop/openlogi.nix
    ../../desktop/virtual-webcam.nix
    ../../desktop/waydroid.nix
  ];

  # The desktop is nixarchy (olafkfreund/nixarchy): Omarchy vendored for
  # NixOS, imported as its NixOS module — its session (through UWSM), Install
  # menu, theme engine and updater. This replaced the port that used to live
  # in nixos/desktop/omarchy (deleted; see docs/nixarchy-gap-analysis.md), of
  # which the deliberate differences merged away are: the UWSM-avoidance
  # (nixarchy runs the session through UWSM) and the vendored hyprland.lua
  # (replaced by the looknfeel.lua user file below). Setting enable to false
  # brings Plasma back; nixos/desktop/kde.nix follows the same switch.
  programs.nixarchy.enable = true;
  programs.nixarchy.user = "rodrigo";
  # `nixarchy-apply` copies ~/.config/nixarchy/apps.nix into this flake before
  # rebuilding. The default is /etc/nixos, which here holds only the stock
  # installer files — not this configuration.
  programs.nixarchy.flake = "/home/rodrigo/Workspace/github.com/rbelem/nix-config";

  # Greeter must select the Nixarchy session (omarchy.desktop): Hyprland's
  # stock uwsm session starts with the user's ~/.config/hypr/hyprland.lua and
  # dies when it does not exist (v0.56: "Couldn't generate default config" →
  # segfault, 2026-10-26 debugging). The Nixarchy session passes --config
  # against the store copy and is unaffected.
  services.displayManager.defaultSession = "omarchy";

  # The omarchy SDDM greeter has no session picker: it picks the FIRST
  # session whose name contains "uwsm" (fair on Arch/omarchy's single
  # session; wrong here, where nixpkgs' generic "Hyprland (uwsm-managed)"
  # entry also matches. nixarchy's own session launches uwsm directly via
  # omarchy-session — that chain is what must stay). So withUWSM keeps
  # nixarchy's default (true), and the generic uwsm desktop is instead
  # dropped from the session list SDDM is handed: the greeter's hunt then
  # misses and falls back to the default session (omarchy), and SDDM's
  # persisted LastSession (/var/lib/sddm/state.conf, root-only) is
  # neutralized the same way, by pointing at a session file that no longer
  # exists. The plain hyprland.desktop goes too: SDDM's session fallback
  # (SessionModel.lastIndex, 0 when state.conf is unreadable) is the
  # alphabetically first entry, so a second session would steal the
  # greeter's default from Nixarchy. Forcing a desktop other than Nixarchy
  # is programs.nixarchy.enable = false (Plasma), not a session pick.
  #
  # SessionDir override instead of `sessionData.desktops`: replacing the
  # shared sessionData wholesale drops the X11 `wrapper` other modules
  # define, and the list option `sessionPackages` cannot subtract the
  # bundled hyprland-uwsm.desktop of the hyprland package.
  services.displayManager.sddm.settings = {
    Wayland.SessionDir = "${desktopsWithoutUwsm}/share/wayland-sessions";
    X11.SessionDir = "${desktopsWithoutUwsm}/share/xsessions";
  };

  # The home-manager module comes in wired to nixarchy's inputs (the
  # installer template pattern); the desktop module's home layer reads the
  # user's home config, so it needs a stateVersion even though the rest of
  # the user is managed on the NixOS side.
  #
  # installer/host.nix (nixarchy's own reference host) wires the HM module
  # with useGlobalPkgs/useUserPackages + sharedModules and turns
  # programs.nixarchy.enable on inside the user: without the shared module
  # import none of nixarchy's home layer ships — the default plugins
  # (including the omarchroma theme plugin the theme engine enables),
  # shell.json defaults or anything else — and the desktop runs on Omarchy's
  # raw bootstrap defaults instead. nixarchyThemeEnginePlugin.service fails
  # without it ("Omarchy Shell did not enable io.github.nobledoodle.omarchroma").
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [ inputs.self.homeManagerModules.nixarchy ];
    users.rodrigo = {
      programs.nixarchy.enable = true;
      home.stateVersion = "26.11";

      # nixarchy only ever references mcp-nixarchy through the versioned store
      # path in the MCP entries it writes; it never installs it. Landing it here
      # puts the command on PATH so it can be run and debugged by hand.
      home.packages = [
        inputs.mcp-nixarchy.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixarchy
      ];
    };
  };

  # nixarchy's session composes Hyprland's settings from ~/.config/hypr —
  # its bootstrap loads the user's looknfeel.lua after Omarchy's defaults —
  # so the scrolling layout arrives as a user file rather than a vendored
  # config. Same values the deleted renderer emitted (hyprland-config.nix,
  # check omarchy-desktop asserted them).
  systemd.tmpfiles.rules =
    let
      looknfeel = pkgs.writeText "looknfeel.lua" ''
        -- niri's layout: the columns scroll sideways instead of shrinking
        -- windows to fit another one.
        hl.config({
          general = {
            layout = "scrolling",
          },
          scrolling = {
            -- 0.4981 leaves a 13px strip of the neighbouring column: enough to
            -- click, and 8:13 is the golden ratio's Fibonacci pair. 0.5 leaves none.
            column_width = 0.4981,
            direction = "right",
            -- 1: clicking a column fits it into view. Safe beside
            -- input.follow_mouse = 2, whose keyboard focus stays put on hover —
            -- a keyboard focus change is what fit the tape uninvited.
            follow_focus = 1,
          },
        })
      '';
      # Derived from keyboard.nix (services.xserver.xkb) so the layout keeps a
      # single source of truth; Hyprland reads its own tree and never sees that
      # option on its own.
      xkb = config.services.xserver.xkb;
      inputLua = pkgs.writeText "input.lua" ''
        hl.config({
          input = {
            ${lib.optionalString (xkb.layout != "") ''kb_layout = "${xkb.layout}",''}
            ${lib.optionalString (xkb.variant != "") ''kb_variant = "${xkb.variant}",''}
            ${lib.optionalString (xkb.options != "") ''kb_options = "${xkb.options}",''}
            repeat_rate = 40,
            repeat_delay = 250,
            numlock_by_default = true,
            -- Two monitors: without this the touchscreen is mapped to whichever
            -- output Hyprland guesses.
            touchdevice = {
              output = "eDP-1",
            },
            -- 2: the pointer surface follows the cursor, so the wheel reaches an
            -- unfocused window, while keyboard focus only moves when crossing
            -- monitors. A keyboard focus change is what runs the scrolling
            -- layout's recalculate fit, which slid the tape on hover at 1.
            follow_mouse = 2,
          },
          -- Hyprland 0.56 has no touchscreen -> tape scroll. Touch.cpp only
          -- focuses a window and, with this, starts a workspace swipe from the
          -- screen edge — that edge swipe is the only scroll a finger can drive.
          gestures = {
            workspace_swipe_touch = true,
          },
        })

        -- Mouse column scrolling. A mouse button cannot modify a bind
        -- ("External events cannot be combined with other keys"), so the thumb
        -- buttons are direct steps rather than hold-and-roll.
        hl.bind("mouse:275", hl.dsp.layout("move +col")) -- back: previous column
        hl.bind("mouse:276", hl.dsp.layout("move -col")) -- forward: next column
      '';
    in
    [
      "L+ /home/rodrigo/.config/hypr/looknfeel.lua - - - - ${looknfeel}"
      "L+ /home/rodrigo/.config/hypr/input.lua - - - - ${inputLua}"
      "L+ /home/rodrigo/.local/share/icons/Yaru-blue - - - - /run/current-system/sw/share/icons/Yaru-blue"
    ];

  # VM-only login for `nixos-rebuild build-vm`. The real machine keeps no
  # password in the repo; the VM gets a throwaway one so the Omarchy greeter
  # accepts a login. vmVariant applies only to the `build-vm` output, never
  # to `switch` or `boot`. No autologin: the point is to see the greeter.
  # mutableUsers is off and the hash is declarative, so the password is
  # enforced on every boot even when the qcow2 is reused across rebuilds
  # (initialPassword only applies when the account is created).
  virtualisation.vmVariant = {
    users.mutableUsers = false;
    users.users.rodrigo.hashedPassword = "$6$2401spiphaYxh0Ah$JquQmmlbhz7xUJyWX4o1xYhm3NBsFV6DyAD197kzqy/r6lv1G9zYMBmldMB8IvqfHBHrp29Ytri8Gprj34Bem/";

    # 3D acceleration for the VM. The default QEMU VGA has no GPU, and
    # Hyprland needs GL to start its renderer. virtio-gpu through virgl gives
    # it one. Host-only: the guest already has Mesa and hardware.graphics
    # enabled.
    virtualisation.qemu.options = [
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };

  boot.tmp.cleanOnBoot = true;

  # Cap the journal (was 1.9G unbounded on a 96G / partition).
  services.journald.settings.Journal.SystemMaxUse = "500M";

  # Cap coredump storage (262M of Aug dumps linger; vacuum only triggers at dump time).
  systemd.coredump.settings.Coredump = {
    MaxUse = "1G";
    ProcessSizeMax = "256M";
  };

  hardware.enableAllFirmware = true;

  # Trust the local user so nix accepts restricted settings per-build.
  # Without this, any flake using `__noChroot = true`,
  # `nixConfig.sandbox = false`, `--no-sandbox`, etc. is silently
  # rejected ("ignoring client-specified setting, you are not a trusted
  # user"). This blocks hermetic-ish builds that need network access
  # mid-build (e.g. devbox.d/bun building bun from source — rustup
  # installs the nightly toolchain, fetch-cli downloads vendor tarballs,
  # cargo pulls crates from the registry).
  #
  # Mirror the rt-ax88u host's setting (line 27 of hosts/rt-ax88u/default.nix).
  nix.settings.trusted-users = [
    "root"
    "rodrigo"
  ];

  # Power management
  services.logind.settings = {
    Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  };

  # Thunderbolt device authorization daemon
  services.hardware.bolt.enable = true;

  # Services
  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    flatpak.enable = true;
    geoclue2.enable = true;
    printing = {
      enable = true;
      drivers = [ pkgs.epson-escpr ];
    };
    udev.packages = [
      pkgs.qmk-udev-rules
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # omarchy theme-switch helpers: killall (psmisc) is called by
  # omarchy-restart-opencode; adw-gtk3 + yaru-theme provide the GTK3 theme
  # and Yaru-blue icon theme the sync-gtk-theme / sync-qt-kde-theme hooks
  # expect (otherwise the theme retint fails and GTK 3 apps stay Adwaita).
  # libsecret carries secret-tool, which the devbox init-hook and bitw use to
  # read the keyring; without it on the system PATH those lookups only work in
  # a shell that already has the devbox profile.
  environment.systemPackages = with pkgs; [
    psmisc
    adw-gtk3
    yaru-theme
    libsecret
    tdf # terminal PDF viewer; draws via the kitty graphics protocol (ghostty)
    # tdf ships no .desktop file, so the default-PDF association below has
    # nothing to point at without this. Ghostty is invoked explicitly because
    # Terminal=true depends on a default terminal being configured in gio.
    (makeDesktopItem {
      name = "tdf";
      desktopName = "tdf";
      comment = "Terminal PDF viewer";
      exec = "ghostty -e tdf %f";
      mimeTypes = [ "application/pdf" ];
      categories = [
        "Office"
        "Viewer"
      ];
    })
  ];

  # PDFs open in tdf from anything that honours xdg-mime (file manager, xdg-open).
  xdg.mime.defaultApplications."application/pdf" = "tdf.desktop";

  system.stateVersion = "23.11"; # Did you read the comment?
}

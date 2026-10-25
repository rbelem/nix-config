# The Omarchy desktop, running on Hyprland's scrolling layout.
#
# Omarchy (https://omarchy.org) is an opinionated Arch-based desktop built
# around Hyprland. This module brings Omarchy's *configuration* to NixOS:
# its keybindings, its themes, its app catalogue and its menu. The compositor
# is nixpkgs' Hyprland with general:layout = scrolling, the niri-style tape of
# columns that niri itself is known for.
#
# What this module does not bring is Omarchy's pacman/update/AUR stack: the
# tree ships it, but there is no pacman on NixOS, so it stays
# vendored-but-unreachable (see README.md). The bar, dock, menu, OSD and lock
# screen are upstream's QuickShell shell (pkgs/omarchy-shell), started with
# the session from the generated Lua configuration.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  inherit (lib) mkIf mkOption mkEnableOption types literalExpression;

  catalogue = import ./apps.nix;

  themeNames = builtins.attrNames (builtins.readDir ./themes);

  theme = builtins.fromTOML (builtins.readFile ./themes/${cfg.theme}/colors.toml);

  # The two settings the GTK half of the theme takes from the palette rather
  # than from the terminal colours: colors.toml names the colour mode, and
  # icons.theme names the icon theme. A theme may omit icons.theme, as
  # upstream's default does, and upstream then falls back to Yaru-blue.
  mode = theme.mode or "dark";

  iconThemeFile = ./themes/${cfg.theme}/icons.theme;

  iconTheme =
    if builtins.pathExists iconThemeFile
    then lib.removeSuffix "\n" (builtins.readFile iconThemeFile)
    else "Yaru-blue";

  terminals = [ "foot" "alacritty" "kitty" "ghostty" ];

  # Where each terminal expects its colours, and where it expects the main
  # configuration that loads them.
  themeTargets = {
    foot = { theme = "foot/themes/omarchy"; config = "foot/foot.ini"; };
    alacritty = { theme = "alacritty/themes/omarchy.toml"; config = "alacritty/alacritty.toml"; };
    kitty = { theme = "kitty/themes/omarchy.conf"; config = "kitty/kitty.conf"; };
    ghostty = { theme = "ghostty/themes/omarchy"; config = "ghostty/config"; };
  };

  # The theme and the configuration that loads it, per terminal.
  renderedThemes = lib.genAttrs terminals (terminal:
    import ./terminal-theme.nix { inherit theme terminal; });

  # Nix has no TOML writer, and the theme is a flat map of strings.
  toToml = attrs:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key} = \"${value}\"") attrs);

  # The greeter theme, vendored from upstream's default/sddm/omarchy.
  sddmTheme = pkgs.runCommand "omarchy-sddm-theme" { } ''
    mkdir -p $out/share/sddm/themes/omarchy
    cp ${./sddm-theme/omarchy/Main.qml} $out/share/sddm/themes/omarchy/Main.qml
    cp ${./sddm-theme/omarchy/metadata.desktop} $out/share/sddm/themes/omarchy/metadata.desktop
    cp ${./sddm-theme/omarchy/theme.conf} $out/share/sddm/themes/omarchy/theme.conf
    cp ${./sddm-theme/omarchy/logo.png} $out/share/sddm/themes/omarchy/logo.png
    cp ${./sddm-theme/omarchy/lock.png} $out/share/sddm/themes/omarchy/lock.png
    cp ${./sddm-theme/omarchy/lock-failed.png} $out/share/sddm/themes/omarchy/lock-failed.png
    cp ${./sddm-theme/omarchy/entry.png} $out/share/sddm/themes/omarchy/entry.png
    cp ${./sddm-theme/omarchy/entry-failed.png} $out/share/sddm/themes/omarchy/entry-failed.png
    cp ${./sddm-theme/omarchy/bullet.png} $out/share/sddm/themes/omarchy/bullet.png
  '';

  enabledApps = lib.filterAttrs (_: app: app.enable) cfg.apps;

  # The command an application is launched with.
  commandOf = pkg: "${pkg}/bin/${pkg.meta.mainProgram or pkg.pname}";

  # The menu commands below name the shell's own commands: the generated Lua
  # configuration runs with the session PATH, where the shell package links
  # its bin/ (see shell.nix). The verbs mirror upstream
  # default/hypr/bindings/utilities.lua; the apps route keeps this module's
  # old fuzzel list as a shell menu route.
  bindings = import ./bindings.nix {
    inherit lib;
    terminal = commandOf cfg.terminal;
    browser = commandOf cfg.browser;
    editor = commandOf cfg.editor;
    fileManager = commandOf cfg.fileManager;
    menu = "omarchy-menu toggle root";
    appsMenu = "omarchy-menu toggle apps";
    systemMenu = "omarchy-menu toggle system";
    keybindings = "omarchy-menu-keybindings";
    swaylock = "${cfg.swaylock}/bin/swaylock";
    wpctl = "${cfg.wireplumber}/bin/wpctl";
    playerctl = "${cfg.playerctl}/bin/playerctl";
    brightnessctl = "${cfg.brightnessctl}/bin/brightnessctl";
    hyprpicker = "${cfg.hyprpicker}/bin/hyprpicker";
  };

  hyprlandConfig = pkgs.writeText "hyprland.lua" (import ./hyprland-config.nix {
    inherit lib bindings theme;
  });

  # The greeter entry. It is a separate package from Hyprland's own session
  # because it passes the generated configuration with --config instead of
  # letting Hyprland find ~/.config/hypr/hyprland.conf.
  sessionPackage = pkgs.symlinkJoin {
    name = "omarchy-session";
    paths = [
      (pkgs.writeTextDir "share/wayland-sessions/omarchy.desktop" ''
        [Desktop Entry]
        Name=Omarchy
        Comment=Omarchy desktop on Hyprland
        Exec=${cfg.package}/bin/start-hyprland -- --config /etc/omarchy/hyprland.lua
        Type=Application
        DesktopNames=Hyprland
      '')
    ];
    # services.displayManager.sessionPackages only accepts packages that say
    # which sessions they provide.
    passthru.providedSessions = [ "omarchy" ];
  };
in
{
  imports = [
    ./install-menu.nix
    ./plugins.nix
    ./theme.nix
    ./appconfigs.nix
    ./update.nix
    ./shims.nix
  ];

  options.programs.omarchy = {
    enable = mkEnableOption "the Omarchy desktop, running on Hyprland's scrolling layout";

    package = mkOption {
      type = types.package;
      default = pkgs.hyprland;
      defaultText = literalExpression "pkgs.hyprland";
      description = ''
        The Hyprland build to use. The scrolling layout comes from this module's
        generated configuration; the GlobalShortcuts portal backend comes from
        the xdg-desktop-portal-hyprland package programs.hyprland installs
        beside it.
      '';
    };

    theme = mkOption {
      type = types.enum themeNames;
      default = "catppuccin";
      description = ''
        Name of an Omarchy theme. The vendored themes are the upstream colour
        palettes under nixos/desktop/omarchy/themes.
      '';
    };

    terminal = mkOption {
      type = types.package;
      default = pkgs.foot;
      description = "The terminal application. Its main program is what the keybindings launch.";
    };

    browser = mkOption {
      type = types.package;
      default = pkgs.firefox;
      description = "The web browser. Its main program is what the keybindings launch.";
    };

    editor = mkOption {
      type = types.package;
      default = pkgs.helix;
      description = "The text editor. Its main program is what the keybindings launch.";
    };

    fileManager = mkOption {
      type = types.package;
      default = pkgs.nautilus;
      description = "The file manager. Its main program is what the keybindings launch.";
    };

    swaylock = mkOption { type = types.package; default = pkgs.swaylock; };
    wireplumber = mkOption { type = types.package; default = pkgs.wireplumber; };
    playerctl = mkOption { type = types.package; default = pkgs.playerctl; };
    brightnessctl = mkOption { type = types.package; default = pkgs.brightnessctl; };
    hyprpicker = mkOption { type = types.package; default = pkgs.hyprpicker; };

    apps = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          enable = mkEnableOption "this app" // { default = false; };
          label = mkOption {
            type = types.str;
            default = if builtins.hasAttr name catalogue then catalogue.${name}.label else name;
            defaultText = literalExpression "the catalogue label";
          };
          category = mkOption {
            type = types.str;
            default = if builtins.hasAttr name catalogue then catalogue.${name}.category else "Utilities";
            defaultText = literalExpression "the catalogue category";
          };
          package = mkOption {
            type = types.package;
            default = pkgs.${if builtins.hasAttr name catalogue then catalogue.${name}.package else name};
            defaultText = literalExpression "the nixpkgs package";
          };
        };
      }));
      default = { };
      description = ''
        Apps to install. The ids are the ones in Omarchy's Install menu; see
        nixos/desktop/omarchy/apps.nix for the catalogue and the nixpkgs
        attribute each one maps to.
      '';
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    # The GTK, icon and cursor half of the theme, applied with gsettings.
    (import ./gtk.nix {
      inherit lib pkgs mode iconTheme;
      theme = cfg.theme;
    })

    # The wallpaper. Upstream's bar draws it; there is no bar here, so swaybg
    # sets it on the layer shell instead.
    (import ./wallpaper.nix { inherit lib pkgs; theme = cfg.theme; })

    (import ./session.nix {
      inherit lib pkgs;
      swaylock = "${cfg.swaylock}/bin/swaylock";
    })

    # The QuickShell shell: OMARCHY_PATH, its bin/ on PATH, and what it
    # spawns by bare name.
    (import ./shell.nix { inherit lib pkgs; })

    # The boot splash. The greeter is not here: SDDM reads the vendored theme
    # in sddm-theme/omarchy, selected below.
    (import ./login.nix { inherit pkgs; })

    {
      programs.hyprland = {
        enable = true;
        package = cfg.package;
      };

      environment.systemPackages =
        map (app: app.package) (lib.attrValues enabledApps)
        ++ [ cfg.terminal cfg.browser cfg.editor cfg.fileManager ];

      services.displayManager.sessionPackages = [ sessionPackage ];

      # The greeter. Plasma's login manager lives in nixos/desktop/kde.nix and
      # is off while the Omarchy desktop is on, so the session needs one.
      # The theme is Omarchy's own SDDM theme, vendored from upstream.
      services.displayManager = {
        sddm.enable = true;
        sddm.theme = "${sddmTheme}/share/sddm/themes/omarchy";
        defaultSession = "omarchy";
      };

      # programs.hyprland routes every interface to the Hyprland portal by
      # default through the package's own portals file; naming the routing
      # here pins GlobalShortcuts to it and puts the rest where Omarchy had
      # them. The Secret interface is gnome-keyring's, which needs the daemon
      # behind it.
      services.gnome.gnome-keyring.enable = true;

      xdg.portal.config.hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.Access" = "gtk";
        "org.freedesktop.impl.portal.Notification" = "gtk";
        "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
        "org.freedesktop.impl.portal.GlobalShortcuts" = "hyprland";
      };

      # The theme is a set of per-application colour files. They are copied into
      # the user's config directory when the session starts, the way Omarchy's
      # omarchy-theme-set does. A main configuration is only written when the
      # user has none, so an existing configuration is never overwritten.
      #
      # The packaged theme is also staged where the shell reads it: the shell
      # treats a symlinked theme as user-owned and writes into it, and the
      # store is read-only, so the tree is copied (never linked) with
      # --no-preserve=mode, plus the theme.name file omarchy-theme-current
      # reads. Re-running converges: the previous staging is removed first.
      systemd.user.services.omarchy-theme = {
        description = "Apply the Omarchy theme";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        script = ''
          set -eu
          config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
          mkdir -p "$config_home"
          ${lib.concatMapStrings (terminal: ''
            install -D -m644 /etc/omarchy/theme/${terminal} "$config_home/${themeTargets.${terminal}.theme}"
            if [ ! -e "$config_home/${themeTargets.${terminal}.config}" ]; then
              install -D -m644 /etc/omarchy/config/${terminal} "$config_home/${themeTargets.${terminal}.config}"
            fi
          '') terminals}
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current"
          mkdir -p "$state_dir"
          rm -rf "$state_dir/theme"
          cp --no-preserve=mode -r ${pkgs.omarchy-shell}/share/omarchy/themes/${cfg.theme} "$state_dir/theme"
          printf '%s\n' ${lib.escapeShellArg cfg.theme} > "$state_dir/theme.name"
        '';
      };

      environment.etc =
        {
          "omarchy/hyprland.lua".source = hyprlandConfig;
          "omarchy/theme/colors.toml".text = toToml theme;
        }
        // lib.listToAttrs (map
          (terminal: {
            name = "omarchy/theme/${terminal}";
            value = { text = renderedThemes.${terminal}.theme; };
          })
          terminals)
        // lib.listToAttrs (map
          (terminal: {
            name = "omarchy/config/${terminal}";
            value = { text = renderedThemes.${terminal}.config; };
          })
          terminals);
    }
  ]);
}

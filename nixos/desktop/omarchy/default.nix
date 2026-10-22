# The Omarchy desktop, running on niri.
#
# Omarchy (https://omarchy.org) is an opinionated Arch-based desktop built
# around Hyprland. This module brings Omarchy's *configuration* to NixOS:
# its keybindings, its themes, its app catalogue and its menu, while niri
# replaces Hyprland as the compositor.
#
# What this module does not bring is Omarchy's QuickShell bar and menu. That
# shell binds to Hyprland's Lua API and to Hyprland's IPC socket, and there is
# no niri equivalent of Quickshell.Hyprland, so the menu becomes a fuzzel
# launcher (launcher.nix) and the bar becomes niri's own workspace overview.
#
# The niri used here is the fork in pkgs/niri-global-shortcuts, which adds the
# GlobalShortcuts portal that upstream niri does not implement.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  inherit (lib) mkIf mkOption mkEnableOption types literalExpression;

  catalogue = import ./apps.nix;

  themeNames = builtins.attrNames (builtins.readDir ./themes);

  theme = builtins.fromTOML (builtins.readFile ./themes/${cfg.theme}/colors.toml);

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

  enabledApps = lib.filterAttrs (_: app: app.enable) cfg.apps;

  # The command an application is launched with.
  commandOf = pkg: "${pkg}/bin/${pkg.meta.mainProgram or pkg.pname}";

  # Command line programs belong in a terminal. How a terminal is told to run
  # a command differs, so the form is picked per terminal.
  runInTerminal = command:
    {
      alacritty = "${commandOf cfg.terminal} -e ${command}";
      ghostty = "${commandOf cfg.terminal} -e ${command}";
    }.${cfg.terminal.pname} or "${commandOf cfg.terminal} ${command}";

  launcher = pkgs.writeShellApplication {
    name = "omarchy-launch";
    runtimeInputs = [ pkgs.fuzzel pkgs.coreutils ];
    text = import ./launcher.nix {
      inherit lib;
      menuEntries = [
        { label = "Applications"; command = "omarchy-launch apps"; }
        { label = "System"; command = "omarchy-launch system"; }
        { label = "Keybindings"; command = "omarchy-launch keybindings"; }
        { label = "Omarchy manual"; command = "xdg-open https://omarchy.org/manual/"; }
        { label = "Niri wiki"; command = "xdg-open https://github.com/YaLTeR/niri/wiki"; }
      ];
      systemEntries = [
        { label = "Lock"; command = "${cfg.swaylock}/bin/swaylock"; }
        { label = "Suspend"; command = "systemctl suspend"; }
        { label = "Log out"; command = "niri msg action quit"; }
        { label = "Reboot"; command = "systemctl reboot"; }
        { label = "Shutdown"; command = "systemctl poweroff"; }
      ];
      appEntries = lib.filter (entry: entry.command != "")
        (lib.sort (a: b: a.category < b.category)
          (lib.mapAttrsToList
            (name: app: {
              inherit (app) label category;
              command =
                if app.category == "Languages" then ""
                else if app.category == "Agents" then runInTerminal (commandOf app.package)
                else commandOf app.package;
            })
            enabledApps));
      keybindingEntries = map
        (bind: { label = bind.key; command = bind.title or bind.action; })
        bindings;
    };
  };

  # The launcher is referenced by name rather than by store path: the launcher
  # script also lists the keybindings, so a store path here would be circular.
  bindings = import ./bindings.nix {
    inherit lib;
    terminal = commandOf cfg.terminal;
    browser = commandOf cfg.browser;
    editor = commandOf cfg.editor;
    fileManager = commandOf cfg.fileManager;
    menu = "omarchy-launch menu";
    appsMenu = "omarchy-launch apps";
    systemMenu = "omarchy-launch system";
    keybindings = "omarchy-launch keybindings";
    swaylock = "${cfg.swaylock}/bin/swaylock";
    wpctl = "${cfg.wireplumber}/bin/wpctl";
    playerctl = "${cfg.playerctl}/bin/playerctl";
    brightnessctl = "${cfg.brightnessctl}/bin/brightnessctl";
    hyprpicker = "${cfg.hyprpicker}/bin/hyprpicker";
  };

  niriConfig = pkgs.writeText "niri.kdl" (import ./niri-config.nix {
    inherit lib bindings theme;
  });

  # The greeter entry. It is a separate package so the session can point niri
  # at the generated configuration instead of the user's own
  # ~/.config/niri/config.kdl.
  sessionPackage = pkgs.symlinkJoin {
    name = "omarchy-session";
    paths = [
      (pkgs.writeTextDir "share/wayland-sessions/omarchy.desktop" ''
        [Desktop Entry]
        Name=Omarchy
        Comment=Omarchy desktop on niri
        Exec=env NIRI_CONFIG=/etc/omarchy/niri.kdl ${cfg.package}/bin/niri-session
        Type=Application
        DesktopNames=niri
      '')
    ];
    # services.displayManager.sessionPackages only accepts packages that say
    # which sessions they provide.
    passthru.providedSessions = [ "omarchy" ];
  };
in
{
  options.programs.omarchy = {
    enable = mkEnableOption "the Omarchy desktop, running on niri";

    package = mkOption {
      type = types.package;
      default = pkgs.niri-global-shortcuts;
      defaultText = literalExpression "pkgs.niri-global-shortcuts";
      description = ''
        The niri build to use. Defaults to the fork in
        pkgs/niri-global-shortcuts, which implements the GlobalShortcuts
        portal. Override to use upstream niri and lose the portal.
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
      default = pkgs.ghostty;
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

  config = mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = cfg.package;
    };

    environment.systemPackages =
      map (app: app.package) (lib.attrValues enabledApps)
      ++ [ launcher cfg.terminal cfg.browser cfg.editor cfg.fileManager ];

    services.displayManager.sessionPackages = [ sessionPackage ];

    # The greeter. Plasma's login manager lives in nixos/desktop/kde.nix and
    # is off while the Omarchy desktop is on, so the session needs one.
    services.displayManager = {
      sddm.enable = true;
      defaultSession = "omarchy";
    };

    # The GlobalShortcuts portal backend lives in the niri fork. Naming it
    # here is what makes xdg-desktop-portal route
    # org.freedesktop.impl.portal.GlobalShortcuts to niri instead of the
    # GNOME backend.
    xdg.portal.config.niri = {
      default = [ "gnome" "gtk" ];
      "org.freedesktop.impl.portal.Access" = "gtk";
      "org.freedesktop.impl.portal.Notification" = "gtk";
      "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      "org.freedesktop.impl.portal.GlobalShortcuts" = "niri";
    };

    # The theme is a set of per-application colour files. They are copied into
    # the user's config directory when the session starts, the way Omarchy's
    # omarchy-theme-set does. A main configuration is only written when the
    # user has none, so an existing configuration is never overwritten.
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
      '';
    };

    environment.etc =
      {
        "omarchy/niri.kdl".source = niriConfig;
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
  };
}

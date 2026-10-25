# The shell's plugin registry: which of its plugins this desktop turns on, and
# the settings each one carries.
#
# Omarchy's shell reads one file for all of it, ~/.config/omarchy/shell.json,
# rendered here from a single attrset so the bar layout, the plugin list and the
# per-plugin settings cannot disagree. That file is canonical rather than
# merged: shell.qml's applyShellConfig replaces the packaged default outright,
# so the whole document is written, including the bar and dock subtrees the
# shell would otherwise take from its own config/omarchy/shell.json.
#
# Two things follow. A bar edit made with `omarchy bar` is overwritten at the
# next login, and array order inside bar.layout is the layout's whole meaning,
# so the shipped order below is written out instead of derived. Object key order
# means nothing to the shell (it JSON.parses the file), and builtins.toJSON
# sorts keys while leaving arrays alone.
#
# Enablement is not one field upstream. A plugin that offers a bar widget is on
# when its id sits in bar.layout; every other first-party plugin is on unless
# its id sits in disabledPlugins, because those are plumbing the shell needs to
# summon them at all. `enable` renders into whichever of the two applies, and
# the split is read off each manifest's `kinds`, so a plugin that is both a
# widget and a menu (omarchy.menu) is toggled as the widget it also is, which is
# what upstream's own toggle does.
#
# Off by default, because the helper they spawn is Arch's and does not exist
# here:
#   omarchy.system-update  polls `omarchy-update-available` and runs
#                          `omarchy-update` on click, both of which drive
#                          pacman. The widget would hold a bar slot and never
#                          light up.
# `omarchy.menu` stays on at upstream's default: its own search and rows work,
# but the rows that install packages run `omarchy-pkg-*`, the same pacman stack,
# so its Install category is dead here (README.md covers the vendored-but-
# unreachable install tree).
#
# A third-party plugin (a settings panel, a package panel, a distrobox panel)
# joins the same table with a manifestPath outside the tree, and renders into
# plugins[] because that is where the shell records a plugin it does not ship.
# An id in programs.omarchy.plugins that this table does not name fails
# evaluation, and an id the rendered file names that the tree no longer ships
# fails the activation service. Neither can silently no-op.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  inherit (lib) mkIf mkOption mkEnableOption types literalExpression;

  tree = "${pkgs.omarchy-shell}/share/omarchy";

  # One record per plugin the shell's manifest scan finds under
  # $OMARCHY_PATH/shell/plugins. `manifest` is the manifest's path inside the
  # tree, `kinds` and `section` are its `kinds` and `barWidget.defaultSection`,
  # `settings` are the settings the shell ships for it in
  # config/omarchy/shell.json, and `enabled` is this module's default. The
  # defaults are upstream's, except omarchy.system-update, above.
  record =
    { manifest, kinds, enabled, section ? null, settings ? { } }:
    { inherit manifest kinds enabled section settings; };

  pluginSet = {
    "omarchy.active-window" = record { manifest = "shell/plugins/bar/widgets/ActiveWindow.manifest.json"; kinds = [ "bar-widget" ]; enabled = false; section = "left"; };
    "omarchy.agents" = record { manifest = "shell/plugins/agents/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.audio" = record { manifest = "shell/plugins/panels/audio/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.background" = record { manifest = "shell/plugins/background/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.bar" = record { manifest = "shell/plugins/bar/manifest.json"; kinds = [ "bar" ]; enabled = true; };
    "omarchy.battery" = record { manifest = "shell/plugins/services/battery/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.bluetooth" = record { manifest = "shell/plugins/panels/bluetooth/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.clipboard" = record { manifest = "shell/plugins/clipboard/manifest.json"; kinds = [ "overlay" ]; enabled = true; };
    "omarchy.clock" = record {
      manifest = "shell/plugins/panels/clock/manifest.json";
      kinds = [ "bar-widget" ];
      enabled = true;
      settings = {
        format = "dddd HH:mm";
        formatAlt = "d MMMM 'W'ww yyyy";
        # The month and weekday divider of the vertical bar, which is upstream's
        # format rather than this file's punctuation.
        verticalFormat = "HH\n—\nmm";
      };
    };
    "omarchy.dev-gallery" = record { manifest = "shell/plugins/dev-gallery/manifest.json"; kinds = [ "panel" ]; enabled = true; };
    "omarchy.disk-speedtest" = record { manifest = "shell/plugins/panels/disk-speedtest/manifest.json"; kinds = [ "panel" ]; enabled = true; };
    "omarchy.dock" = record { manifest = "shell/plugins/dock/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.dropbox" = record { manifest = "shell/plugins/panels/dropbox/manifest.json"; kinds = [ "bar-widget" ]; enabled = false; section = "right"; };
    "omarchy.elsewhen" = record { manifest = "shell/plugins/panels/elsewhen/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; section = "right"; };
    "omarchy.emojis" = record { manifest = "shell/plugins/emojis/manifest.json"; kinds = [ "overlay" ]; enabled = true; };
    "omarchy.idle" = record { manifest = "shell/plugins/services/idle/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.image-picker" = record { manifest = "shell/plugins/image-picker/manifest.json"; kinds = [ "overlay" ]; enabled = true; };
    "omarchy.indicators" = record { manifest = "shell/plugins/bar/widgets/Indicators.manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.keyboard-layout" = record { manifest = "shell/plugins/bar/widgets/KeyboardLayout.manifest.json"; kinds = [ "bar-widget" ]; enabled = true; section = "right"; };
    "omarchy.lock" = record { manifest = "shell/plugins/lock/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.media" = record { manifest = "shell/plugins/services/media/manifest.json"; kinds = [ "service" "bar-widget" ]; enabled = false; };
    "omarchy.menu" = record { manifest = "shell/plugins/menu/manifest.json"; kinds = [ "menu" "bar-widget" ]; enabled = true; };
    "omarchy.microphone" = record { manifest = "shell/plugins/bar/widgets/Microphone.manifest.json"; kinds = [ "bar-widget" ]; enabled = false; };
    "omarchy.monitor" = record { manifest = "shell/plugins/panels/monitor/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.network" = record { manifest = "shell/plugins/panels/network/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.nightlight" = record { manifest = "shell/plugins/services/nightlight/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.notifications" = record { manifest = "shell/plugins/notifications/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.osd" = record { manifest = "shell/plugins/osd/manifest.json"; kinds = [ "panel" ]; enabled = true; };
    "omarchy.polkit" = record { manifest = "shell/plugins/polkit/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.power" = record { manifest = "shell/plugins/panels/power/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.remote-session" = record { manifest = "shell/plugins/services/remote-session/manifest.json"; kinds = [ "service" ]; enabled = true; };
    "omarchy.reminders" = record { manifest = "shell/plugins/reminders/manifest.json"; kinds = [ "overlay" ]; enabled = true; };
    "omarchy.spacer" = record { manifest = "shell/plugins/bar/widgets/Spacer.manifest.json"; kinds = [ "bar-widget" ]; enabled = false; };
    "omarchy.speedtest" = record { manifest = "shell/plugins/panels/speedtest/manifest.json"; kinds = [ "panel" ]; enabled = true; };
    # Off for the pacman reason in the header, and the only row whose default
    # differs from upstream's bar layout.
    "omarchy.system-update" = record { manifest = "shell/plugins/bar/widgets/SystemUpdate.manifest.json"; kinds = [ "bar-widget" ]; enabled = false; };
    "omarchy.tailscale" = record { manifest = "shell/plugins/panels/tailscale/manifest.json"; kinds = [ "bar-widget" ]; enabled = false; section = "right"; };
    "omarchy.tray" = record { manifest = "shell/plugins/bar/widgets/Tray.manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.weather" = record { manifest = "shell/plugins/panels/weather/manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
    "omarchy.wifiqr" = record { manifest = "shell/plugins/panels/wifiqr/manifest.json"; kinds = [ "panel" ]; enabled = true; };
    "omarchy.workspaces" = record { manifest = "shell/plugins/bar/widgets/Workspaces.manifest.json"; kinds = [ "bar-widget" ]; enabled = true; };
  };

  # The layout the tree ships, in its order.
  sections = [ "left" "centerBegin" "center" "centerEnd" "right" ];

  shippedLayout = {
    left = [ "omarchy.menu" "omarchy.workspaces" ];
    centerBegin = [ "omarchy.indicators" ];
    center = [ "omarchy.clock" ];
    centerEnd = [ "omarchy.elsewhen" "omarchy.weather" "omarchy.system-update" ];
    right = [
      "omarchy.tray"
      "omarchy.keyboard-layout"
      "omarchy.agents"
      "omarchy.bluetooth"
      "omarchy.network"
      "omarchy.audio"
      "omarchy.monitor"
      "omarchy.power"
    ];
  };

  isWidget = rv: builtins.elem "bar-widget" rv.kinds;
  firstParty = rv: lib.hasPrefix "${tree}/" rv.manifestPath;

  # A bar widget's settings live in its layout entry; every other plugin's live
  # in its plugins[] entry, which is the slot the shell reads either way.
  entry = rv: rv.settings // { id = rv.id; };

  resolved = lib.mapAttrs
    (id: p:
      let declared = cfg.plugins.${id} or { }; in
      {
        inherit id;
        inherit (p) kinds section;
        manifestPath = "${tree}/${p.manifest}";
        enabled = declared.enable or p.enabled;
        settings = p.settings // (declared.settings or { });
      })
    pluginSet;

  inShippedLayout = id:
    builtins.elem id (lib.concatMap (section: shippedLayout.${section}) sections);

  # A widget the shipped layout does not name goes where its manifest asks, or
  # beside the clock when it asks for nowhere, which is the section the shell
  # itself falls back to.
  addedSection = rv: if rv.section == null then "centerEnd" else rv.section;

  added = builtins.filter
    (rv: isWidget rv && rv.enabled && !(inShippedLayout rv.id))
    (lib.attrValues resolved);

  barLayout = lib.genAttrs sections (section:
    map (id: entry resolved.${id}) (builtins.filter (id: resolved.${id}.enabled) shippedLayout.${section})
    ++ map entry (builtins.filter (rv: addedSection rv == section) added));

  # Only a first-party plugin needs saying out loud when it is off; a widget
  # that is off is simply absent from the layout above.
  disabledIds = map
    (rv: rv.id)
    (builtins.filter (rv: firstParty rv && !isWidget rv && !rv.enabled) (lib.attrValues resolved));

  pluginEntries = map entry (builtins.filter
    (rv: !(firstParty rv) && !isWidget rv && rv.enabled)
    (lib.attrValues resolved));

  # Upstream's defaults for the two subtrees that belong to no plugin. Dock pins
  # are desktop-entry ids, and the dock drops a pin whose entry does not exist
  # (Dock.qml's `items`), so the shipped list costs nothing until an app is
  # installed.
  shellConfig = {
    version = 1;
    idle = { screensaver = 150; lock = 300; };
    bar = { position = "top"; background = "opaque"; layout = barLayout; };
    dock = {
      position = "bottom";
      pinned = [ "org.gnome.Nautilus" "chromium" "foot" "omacalc" "omawrite" "X" "YouTube" ];
    };
    plugins = pluginEntries;
  } // lib.optionalAttrs (disabledIds != [ ]) { disabledPlugins = disabledIds; };

  shellConfigFile = pkgs.writeText "omarchy-shell.json" (builtins.toJSON shellConfig + "\n");

  unknownIds = lib.subtractLists (builtins.attrNames pluginSet) (builtins.attrNames cfg.plugins);
in
{
  options.programs.omarchy.plugins = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        enable = mkEnableOption "this plugin" // {
          default = pluginSet.${name}.enabled or false;
          defaultText = literalExpression "the default this module records for it";
        };
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = pluginSet.${name}.settings or { };
          defaultText = literalExpression "the settings the shell ships for it";
          description = ''
            Settings written into this plugin's shell.json entry, merged over
            the ones the shell ships. Values have to be JSON-encodable: a
            function, path or derivation fails evaluation when the file is
            rendered. A key the plugin does not read is inert.
          '';
        };
      };
    }));
    default = { };
    description = ''
      Plugins of Omarchy's shell, by the id in their manifest. Every id is a
      dotted string, so a definition quotes it:
      `programs.omarchy.plugins."omarchy.clock".settings.format = "HH:mm"`.

      The ids are the ones the packaged tree ships. A plugin that is not in
      nixos/desktop/omarchy/plugins.nix fails evaluation rather than being
      written into a file the shell reads and ignores.
    '';
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = unknownIds == [ ];
        message =
          "programs.omarchy.plugins names ${lib.concatStringsSep ", " unknownIds}, "
          + "which the shell tree does not ship. Its plugins are: "
          + lib.concatStringsSep " " (builtins.attrNames pluginSet) + ".";
      }
      {
        assertion = resolved."omarchy.bar".enabled;
        message =
          "programs.omarchy.plugins.\"omarchy.bar\".enable = false leaves the "
          + "desktop with no bar. The tree ships one bar plugin, so there is "
          + "nothing for the shell to fall back to.";
      }
    ];

    environment.etc."omarchy/shell.json".source = shellConfigFile;

    # The shell reads the file at startup and watches it afterwards
    # (shell.qml's userConfigFile), so a write after the session has started
    # still lands.
    systemd.user.services.omarchy-shell-config = {
      description = "Install the declared Omarchy shell plugin registry";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = ''
        set -eu

        # Every id the rendered file names is one this module believed the tree
        # ships. One that it no longer ships is a registry row that outlived its
        # plugin, and the shell would drop it without a word, so it fails here
        # instead, where the message can name it.
        ships=$(find ${tree}/shell/plugins -type f \
          \( -name manifest.json -o -name '*.manifest.json' \) \
          -exec jq -r .id {} + | sort -u)
        named=$(jq -r '(.plugins[]?.id), (.disabledPlugins[]?), (.bar.layout | .[] | .[] | .id)' \
          ${shellConfigFile} | sort -u)

        for id in $named; do
          printf '%s\n' "$ships" | grep -qxF -- "$id" || {
            echo "omarchy shell.json names $id, which the shell tree does not ship" >&2
            exit 1
          }
        done

        config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        install -D -m644 ${shellConfigFile} "$config_home/omarchy/shell.json"
      '';
    };
  };
}

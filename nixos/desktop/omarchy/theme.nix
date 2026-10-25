# Runtime theme switching.
#
# programs.omarchy.theme is the login default. default.nix bakes it into the
# terminals' main configurations, the wallpaper unit and the generated
# Hyprland configuration, and its omarchy-theme oneshot stages that one theme
# into ~/.local/state/omarchy/current on every login.
#
# `omarchy-theme-switch <name>` moves the staged state to another packaged
# theme without a rebuild, then hands the change to the consumers of it. The
# state is one value:
#
#   name       ~/.local/state/omarchy/current/theme.name
#   source     the packaged theme it is copied from
#   staged     ~/.local/state/omarchy/current/theme
#   consumers  every reader below, each reached by one kind of hand-off
#
#   shell      the staged colors.toml over the shell's applyTheme IPC
#   terminals  the palette file each terminal configuration already includes
#   swaybg     omarchy-wallpaper.service
#   GTK        omarchy-gtk.service
#
# The staged copy is what the login oneshot copies for the same name, and the
# terminal palettes come from terminal-theme.nix, the function the oneshot's
# files are rendered by. A switch and a login therefore cannot disagree about
# what a theme looks like.
#
# `omarchy-theme-current` prints the staged name, and takes precedence over the
# shell package's command of the same name, which prints it title-cased.
#
# Three surfaces still take the theme at build time and so cannot follow a
# switch: the wallpaper image path (wallpaper.nix), the GTK keys (gtk.nix) and
# Hyprland's border colours (hyprland-config.nix). Restarting the first two is
# a no-op until they read the staged theme; the script says so rather than
# implying the wallpaper changed.
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.omarchy;

  inherit (lib) concatMapStringsSep concatStringsSep escapeShellArg mkIf;

  # The themes the shell package ships. This is the tree the login oneshot
  # copies from, so it is also the set a switch may take.
  themes = "${pkgs.omarchy-shell}/share/omarchy/themes";

  # The vendored copy of the same set, which is what the module option
  # enumerates and what the palettes are rendered from.
  themeNames = builtins.attrNames (builtins.readDir ./themes);

  terminals = [ "foot" "alacritty" "kitty" "ghostty" ];

  # The file each terminal loads its colours from, as terminal-theme.nix writes
  # the main configuration that loads it: foot includes themes/omarchy,
  # alacritty imports themes/omarchy.toml, kitty includes themes/omarchy.conf,
  # ghostty config-files themes/omarchy.
  terminalTargets = {
    foot = "foot/themes/omarchy";
    alacritty = "alacritty/themes/omarchy.toml";
    kitty = "kitty/themes/omarchy.conf";
    ghostty = "ghostty/themes/omarchy";
  };

  # Every consumer of the staged theme, and how the switch reaches it.
  consumers = {
    shell = { kind = "ipc"; };
    terminals = { kind = "files"; };
    swaybg = { kind = "unit"; unit = "omarchy-wallpaper.service"; };
    gtk = { kind = "unit"; unit = "omarchy-gtk.service"; };
  };

  unitConsumers = lib.mapAttrsToList (_: consumer: consumer.unit)
    (lib.filterAttrs (_: consumer: consumer.kind == "unit") consumers);

  # The theme is the only runtime input to a palette, and there are finitely
  # many packaged themes, so every palette is rendered here instead of at
  # switch time. Same renderer, so the files match a login for the same name.
  palettes = pkgs.linkFarm "omarchy-theme-palettes" (lib.concatMap
    (name: map
      (terminal: {
        name = "${name}/${terminal}";
        path = pkgs.writeText "omarchy-${name}-${terminal}"
          (import ./terminal-theme.nix {
            theme = builtins.fromTOML (builtins.readFile ./themes/${name}/colors.toml);
            inherit terminal;
          }).theme;
      })
      terminals)
    themeNames);

  switch = pkgs.writeShellApplication {
    name = "omarchy-theme-switch";
    runtimeInputs = [ pkgs.coreutils pkgs.systemd pkgs.util-linux pkgs.omarchy-shell ];
    text = ''
      themes=${themes}
      palettes=${palettes}
      state="$HOME/.local/state/omarchy/current"
      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      login_default=${escapeShellArg cfg.theme}

      # The IPC client reads the tree it was built from, and a switch started
      # outside the session (a TTY, a unit) has no OMARCHY_PATH of its own.
      export OMARCHY_PATH=${pkgs.omarchy-shell}/share/omarchy

      list_themes() {
        local path
        printf 'Packaged themes:\n'
        for path in "$themes"/*/; do
          path=''${path%/}
          printf '  %s\n' "''${path##*/}"
        done
      }

      if [ $# -ne 1 ]; then
        printf 'Usage: omarchy-theme-switch <theme>\n\nSwitch the running Omarchy theme without a rebuild.\n' >&2
        list_themes >&2
        exit 2
      fi

      # Upstream names themes lowercase and hyphenated, and its picker shows
      # them title-cased, so accept the name as shown there.
      name=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
      if [[ ! $name =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        printf 'Invalid theme name: %s\n' "$1" >&2
        list_themes >&2
        exit 1
      fi
      if [ ! -d "$themes/$name" ] || [ ! -d "$palettes/$name" ]; then
        printf 'Unknown theme: %s\n' "$1" >&2
        list_themes >&2
        exit 1
      fi

      mkdir -p "$state"
      # The staged tree is the one piece of shared state, so two switches take
      # turns instead of interleaving their copies.
      exec 9>"$state/switch.lock"
      flock 9

      rm -rf "$state/next-theme"
      cp -r --no-preserve=mode "$themes/$name" "$state/next-theme"
      rm -rf "$state/theme"
      mv "$state/next-theme" "$state/theme"
      printf '%s\n' "$name" >"$state/theme.name"

      ${concatMapStringsSep "\n" (terminal:
        ''install -D -m644 "$palettes/$name/${terminal}" "$config_home/${terminalTargets.${terminal}}"''
      ) terminals}

      printf 'theme:    %s\n' "$name"
      printf 'source:   %s\n' "$themes/$name"
      printf 'staged:   %s\n' "$state/theme"
      printf 'name:     %s\n' "$state/theme.name"
      printf 'palettes: %s\n' "${concatMapStringsSep " " (terminal: "$config_home/${terminalTargets.${terminal}}") terminals}"

      colors=""
      if [ -f "$state/theme/colors.toml" ]; then
        colors=$(base64 -w0 "$state/theme/colors.toml")
      fi
      shell_values=""
      if [ -f "$state/theme/shell.toml" ]; then
        shell_values=$(base64 -w0 "$state/theme/shell.toml")
      fi
      if omarchy-shell shell applyTheme "$colors" "$shell_values" >/dev/null 2>&1; then
        printf 'shell:    palette applied over IPC\n'
      else
        printf 'shell:    not running, so it reads the staged palette when it starts\n'
      fi

      for unit in ${concatStringsSep " " unitConsumers}; do
        if systemctl --user --quiet restart "$unit" 2>/dev/null; then
          printf '%s: restarted\n' "$unit"
        else
          printf '%s: not restarted, no user manager\n' "$unit"
        fi
      done

      printf '\n'
      printf 'Running terminals keep the old palette: foot re-reads its colours only\n'
      printf 'at launch, so it needs a restart. kitty re-reads on SIGUSR1, ghostty on\n'
      printf 'SIGUSR2, and alacritty when its own config file is touched. This command\n'
      printf 'touches none of them; new terminals start on the new palette.\n'
      printf '\n'
      printf 'The wallpaper, the GTK keys and the Hyprland borders stay %s: their\n' "$login_default"
      printf 'units and the compositor configuration take the theme at build time, so\n'
      printf 'the restart above changes nothing until they read the staged theme.\n'
      printf 'This switch does not survive logout either: programs.omarchy.theme is\n'
      printf 'still %s and the login service restages it. Persisting the choice needs\n' "$login_default"
      printf 'home-manager, which this host does not use.\n'
    '';
  };

  current = pkgs.writeShellApplication {
    name = "omarchy-theme-current";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      name_file="$HOME/.local/state/omarchy/current/theme.name"
      if [ -s "$name_file" ]; then
        cat "$name_file"
      else
        # Nothing staged yet: the login default is what the session applies.
        printf '%s\n' ${escapeShellArg cfg.theme}
      fi
    '';
  };

  commands = pkgs.symlinkJoin {
    name = "omarchy-theme-commands";
    paths = [ switch current ];
    meta.description = "Omarchy theme switch and current-theme commands";
  };
in
{
  config = mkIf cfg.enable {
    # omarchy-shell ships an omarchy-theme-current of its own, and
    # environment.systemPackages keeps the first of two colliding names. mkBefore
    # puts this package ahead of the shell's, so the command that answers is the
    # one whose output a switch accepts back.
    environment.systemPackages = lib.mkBefore [ commands ];
  };
}

# The Omarchy menu, as a fuzzel launcher.
#
# Omarchy renders its menu in a QuickShell application. That shell binds to
# Hyprland's IPC, so it cannot run under niri. This launcher keeps a subset
# of the menu's entries and replaces its presentation: one fuzzel list per
# menu, with the same actions.
{ lib, menuEntries, systemEntries, appEntries, keybindingEntries }:

let
  toTsv = entries:
    lib.concatStringsSep "\n" (map (entry: "${entry.label}\t${entry.command}") entries);
in
''
  menu_data=${lib.escapeShellArg (toTsv menuEntries)}
  system_data=${lib.escapeShellArg (toTsv systemEntries)}
  apps_data=${lib.escapeShellArg (toTsv appEntries)}
  keys_data=${lib.escapeShellArg (toTsv keybindingEntries)}

  mode="''${1:-menu}"
  case "$mode" in
    menu) data=$menu_data; prompt="Omarchy> "; run=1 ;;
    apps) data=$apps_data; prompt="Apps> "; run=1 ;;
    system) data=$system_data; prompt="System> "; run=1 ;;
    keybindings) data=$keys_data; prompt="Keybindings> "; run=0 ;;
    *)
      echo "omarchy-launch: unknown menu '$mode'" >&2
      exit 2
      ;;
  esac

  selected=$(printf '%s\n' "$data" | fuzzel --dmenu --prompt "$prompt") || exit 0

  if [ "$run" -eq 1 ]; then
    command=$(printf '%s\n' "$selected" | cut -f2)
    if [ -n "$command" ]; then
      exec sh -c "$command"
    fi
  else
    printf '%s\n' "$selected"
  fi
''

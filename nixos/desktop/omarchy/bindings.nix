# Omarchy's default keybindings, ported to niri.
#
# Omarchy ships these as Hyprland Lua (default/hypr/bindings/*.lua upstream).
# Hyprland and niri are both tiling Wayland compositors, but their models
# differ enough that this is a semantic port, not a transliteration:
#
#   Hyprland                    niri
#   --------------------------  ---------------------------------------
#   split toggle                none (niri's scrolling layout has no split)
#   pseudo window               none
#   scratchpad / special ws     none (niri has dynamic named workspaces)
#   window groups               none
#   "focus left window"         focus-column-left
#   "workspace 1..10"           focus-workspace-1..10
#
# Every binding with no niri equivalent is listed in
# nixos/desktop/omarchy/README.md under "What did not come across", with the
# reason.
#
# Arguments:
#   terminal     command for the terminal app
#   browser      command for the web browser
#   editor       command for the text editor
#   fileManager  command for the file manager
#   menu         command that opens the Omarchy menu
#   appsMenu     command that opens the application launcher
#   systemMenu   command that opens the power/system menu
#   keybindings  command that shows the keybinding reference
#   swaylock     screen locker binary
#   wpctl        PipeWire control binary
#   playerctl    MPRIS control binary
#   brightnessctl backlight control binary
#   hyprpicker   colour picker binary
{ lib
, terminal
, browser
, editor
, fileManager
, menu
, appsMenu
, systemMenu
, keybindings
, swaylock
, wpctl
, playerctl
, brightnessctl
, hyprpicker
}:

let
  # niri's number keys only reach 9, but the tenth workspace is reached with
  # the 0 key, the way Omarchy reaches it with code:19.
  workspaceBinds = map (n: {
    key = "Super+${toString n}";
    action = "focus-workspace ${toString n}";
    title = "Focus workspace ${toString n}";
  }) (lib.range 1 9)
  ++ [ {
    key = "Super+0";
    action = "focus-workspace 10";
    title = "Focus workspace 10";
  } ];

  workspaceMoveBinds = map (n: {
    key = "Super+Shift+${toString n}";
    action = "move-window-to-workspace ${toString n}";
    title = "Move window to workspace ${toString n}";
  }) (lib.range 1 9)
  ++ [ {
    key = "Super+Shift+0";
    action = "move-window-to-workspace 10";
    title = "Move window to workspace 10";
  } ];
in
[
  # ── Window management ───────────────────────────────────────────────
  { key = "Super+W"; action = "close-window"; title = "Close window"; }
  { key = "Super+Q"; action = "close-window"; title = "Close window"; }
  { key = "Super+T"; action = "toggle-window-floating"; title = "Toggle window floating"; }
  { key = "Super+F"; action = "fullscreen-window"; title = "Full screen"; }
  { key = "Super+Ctrl+F"; action = "toggle-windowed-fullscreen"; title = "Tiled full screen"; }
  { key = "Super+Alt+F"; action = "maximize-column"; title = "Maximize column"; }
  { key = "Super+O"; action = "toggle-window-floating"; title = "Float the window"; }
  { key = "Super+Home"; action = "focus-column-first"; title = "Focus the first column"; }
  { key = "Super+End"; action = "focus-column-last"; title = "Focus the last column"; }

  # ── Focus ───────────────────────────────────────────────────────────
  { key = "Super+Left"; action = "focus-column-left"; title = "Focus the column on the left"; }
  { key = "Super+Right"; action = "focus-column-right"; title = "Focus the column on the right"; }
  { key = "Super+Up"; action = "focus-window-up"; title = "Focus the window above"; }
  { key = "Super+Down"; action = "focus-window-down"; title = "Focus the window below"; }
  { key = "Alt+Tab"; action = "focus-window-previous"; title = "Focus the previous window"; }
  { key = "Ctrl+Alt+Tab"; action = "focus-monitor-next"; title = "Focus the next monitor"; }
  { key = "Ctrl+Alt+Shift+Tab"; action = "focus-monitor-previous"; title = "Focus the previous monitor"; }

  # ── Move ────────────────────────────────────────────────────────────
  { key = "Super+Ctrl+Left"; action = "move-column-left"; title = "Move the column left"; }
  { key = "Super+Ctrl+Right"; action = "move-column-right"; title = "Move the column right"; }
  { key = "Super+Ctrl+Up"; action = "move-window-up"; title = "Move the window up"; }
  { key = "Super+Ctrl+Down"; action = "move-window-down"; title = "Move the window down"; }
  # niri has no vertical swap: its layout scrolls sideways.
  { key = "Super+Shift+Left"; action = "swap-window-left"; title = "Swap with the window on the left"; }
  { key = "Super+Shift+Right"; action = "swap-window-right"; title = "Swap with the window on the right"; }

  # ── Workspaces ──────────────────────────────────────────────────────
  { key = "Super+Tab"; action = "focus-workspace-down"; title = "Next workspace"; }
  { key = "Super+Shift+Tab"; action = "focus-workspace-up"; title = "Previous workspace"; }
  { key = "Super+Ctrl+Tab"; action = "focus-workspace-previous"; title = "Former workspace"; }
  { key = "Super+Shift+Alt+Left"; action = "move-workspace-to-monitor-left"; title = "Move the workspace to the left monitor"; }
  { key = "Super+Shift+Alt+Right"; action = "move-workspace-to-monitor-right"; title = "Move the workspace to the right monitor"; }
  { key = "Super+Shift+Alt+Up"; action = "move-workspace-to-monitor-up"; title = "Move the workspace to the upper monitor"; }
  { key = "Super+Shift+Alt+Down"; action = "move-workspace-to-monitor-down"; title = "Move the workspace to the lower monitor"; }
  { key = "Super+Shift+Ctrl+Left"; action = "move-window-to-monitor-left"; title = "Move the window to the left monitor"; }
  { key = "Super+Shift+Ctrl+Right"; action = "move-window-to-monitor-right"; title = "Move the window to the right monitor"; }
  { key = "Super+Shift+Ctrl+Up"; action = "move-window-to-monitor-up"; title = "Move the window to the upper monitor"; }
  { key = "Super+Shift+Ctrl+Down"; action = "move-window-to-monitor-down"; title = "Move the window to the lower monitor"; }

  # ── Resize ───────────────────────────────────────────────────────────
  # Omarchy resizes the window by a fixed number of pixels. niri resizes the
  # column, and does it by cycling through preset widths.
  { key = "Super+minus"; action = "switch-preset-column-width"; title = "Widen the column"; }
  { key = "Super+equal"; action = "switch-preset-column-width-back"; title = "Narrow the column"; }
  { key = "Super+Shift+minus"; action = "switch-preset-window-height"; title = "Make the window taller"; }
  { key = "Super+Shift+equal"; action = "switch-preset-window-height-back"; title = "Make the window shorter"; }

  # ── Applications ────────────────────────────────────────────────────
  { key = "Super+Return"; action = "spawn \"${terminal}\""; title = "Terminal"; }
  { key = "Super+Shift+Return"; action = "spawn \"${browser}\""; title = "Browser"; }
  { key = "Super+Shift+B"; action = "spawn \"${browser}\""; title = "Browser"; }
  { key = "Super+Shift+F"; action = "spawn \"${fileManager}\""; title = "File manager"; }
  { key = "Super+Shift+N"; action = "spawn \"${editor}\""; title = "Editor"; }

  # ── Omarchy menu ────────────────────────────────────────────────────
  { key = "Super+Space"; action = "spawn-sh \"${menu}\""; title = "Omarchy menu"; }
  { key = "Super+Alt+Space"; action = "spawn-sh \"${appsMenu}\""; title = "Applications"; }
  { key = "Super+Escape"; action = "spawn-sh \"${systemMenu}\""; title = "System menu"; }
  { key = "Super+K"; action = "spawn-sh \"${keybindings}\""; title = "Keybindings"; }

  # ── Screenshots and screen capture ──────────────────────────────────
  { key = "Print"; action = "screenshot-screen"; title = "Screenshot"; }
  { key = "Super+Shift+S"; action = "screenshot-screen"; title = "Screenshot"; }
  { key = "Super+Print"; action = "spawn-sh \"${hyprpicker} -a\""; title = "Colour picker"; }

  # ── Session ─────────────────────────────────────────────────────────
  { key = "Super+Ctrl+L"; action = "spawn-sh \"${swaylock}\""; title = "Lock the screen"; }
  { key = "XF86PowerOff"; action = "spawn-sh \"${systemMenu}\""; title = "Power menu"; props = "allow-when-locked=true"; }

  # ── Audio, brightness and media ─────────────────────────────────────
  {
    key = "XF86AudioRaiseVolume";
    action = "spawn-sh \"${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0\"";
    title = "Volume up";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86AudioLowerVolume";
    action = "spawn-sh \"${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 0.1- -l 1.0\"";
    title = "Volume down";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86AudioMute";
    action = "spawn-sh \"${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle\"";
    title = "Mute";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86AudioMicMute";
    action = "spawn-sh \"${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle\"";
    title = "Mute the microphone";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86MonBrightnessUp";
    action = "spawn-sh \"${brightnessctl} set +10%\"";
    title = "Brightness up";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86MonBrightnessDown";
    action = "spawn-sh \"${brightnessctl} set 10%-\"";
    title = "Brightness down";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86AudioPlay";
    action = "spawn-sh \"${playerctl} play-pause\"";
    title = "Play or pause";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86AudioNext";
    action = "spawn-sh \"${playerctl} next\"";
    title = "Next track";
    props = "allow-when-locked=true";
  }
  {
    key = "XF86AudioPrev";
    action = "spawn-sh \"${playerctl} previous\"";
    title = "Previous track";
    props = "allow-when-locked=true";
  }
]
++ workspaceBinds
++ workspaceMoveBinds

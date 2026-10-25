# Omarchy's default keybindings, as Hyprland dispatcher calls.
#
# Omarchy ships these as Hyprland Lua (default/hypr/bindings/*.lua upstream).
# Each entry is {key, action, title, props?}: `key` is the readable form the
# keybinding list shows, `action` is the call Hyprland runs, `title` is its
# one-line description, and `props` holds the bind flags for the keys that
# are not a plain `bind` ("l" is a key that still fires while the session is
# locked).
#
# Every binding with no Hyprland equivalent is listed in
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
  # Hyprland's workspace dispatchers take the number directly, and the tenth
  # workspace is reached with the 0 key, the way Omarchy reaches it with
  # code:19.
  workspaceBinds = map (n: {
    key = "Super+${toString n}";
    action = "workspace,${toString n}";
    title = "Focus workspace ${toString n}";
  }) (lib.range 1 9)
  ++ [ {
    key = "Super+0";
    action = "workspace,10";
    title = "Focus workspace 10";
  } ];

  workspaceMoveBinds = map (n: {
    key = "Super+Shift+${toString n}";
    action = "movetoworkspace,${toString n}";
    title = "Move window to workspace ${toString n}";
  }) (lib.range 1 9)
  ++ [ {
    key = "Super+Shift+0";
    action = "movetoworkspace,10";
    title = "Move window to workspace 10";
  } ];
in
[
  # ── Window management ───────────────────────────────────────────────
  { key = "Super+W"; action = "killactive"; title = "Close window"; }
  { key = "Super+Q"; action = "killactive"; title = "Close window"; }
  { key = "Super+T"; action = "togglefloating"; title = "Toggle window floating"; }
  { key = "Super+F"; action = "fullscreen,0"; title = "Full screen"; }
  # Maximized is Hyprland's mode that fills the work area and stays in the
  # layout, which is niri's windowed fullscreen.
  { key = "Super+Ctrl+F"; action = "fullscreen,1"; title = "Tiled full screen"; }
  { key = "Super+Alt+F"; action = "layoutmsg,fit active"; title = "Maximize column"; }
  { key = "Super+O"; action = "togglefloating"; title = "Float the window"; }

  # ── Focus ───────────────────────────────────────────────────────────
  { key = "Super+Left"; action = "movefocus,l"; title = "Focus the column on the left"; }
  { key = "Super+Right"; action = "movefocus,r"; title = "Focus the column on the right"; }
  { key = "Super+Up"; action = "movefocus,u"; title = "Focus the window above"; }
  { key = "Super+Down"; action = "movefocus,d"; title = "Focus the window below"; }
  { key = "Alt+Tab"; action = "focuscurrentorlast"; title = "Focus the previous window"; }
  { key = "Ctrl+Alt+Tab"; action = "focusmonitor,+1"; title = "Focus the next monitor"; }
  { key = "Ctrl+Alt+Shift+Tab"; action = "focusmonitor,-1"; title = "Focus the previous monitor"; }

  # ── Move ────────────────────────────────────────────────────────────
  { key = "Super+Ctrl+Left"; action = "movewindow,l"; title = "Move the column left"; }
  { key = "Super+Ctrl+Right"; action = "movewindow,r"; title = "Move the column right"; }
  { key = "Super+Ctrl+Up"; action = "movewindow,u"; title = "Move the window up"; }
  { key = "Super+Ctrl+Down"; action = "movewindow,d"; title = "Move the window down"; }
  { key = "Super+Shift+Left"; action = "swapwindow,l"; title = "Swap with the window on the left"; }
  { key = "Super+Shift+Right"; action = "swapwindow,r"; title = "Swap with the window on the right"; }

  # ── Workspaces ──────────────────────────────────────────────────────
  { key = "Super+Tab"; action = "workspace,e+1"; title = "Next workspace"; }
  { key = "Super+Shift+Tab"; action = "workspace,e-1"; title = "Previous workspace"; }
  { key = "Super+Ctrl+Tab"; action = "workspace,previous"; title = "Former workspace"; }
  { key = "Super+Shift+Alt+Left"; action = "movecurrentworkspacetomonitor,l"; title = "Move the workspace to the left monitor"; }
  { key = "Super+Shift+Alt+Right"; action = "movecurrentworkspacetomonitor,r"; title = "Move the workspace to the right monitor"; }
  { key = "Super+Shift+Alt+Up"; action = "movecurrentworkspacetomonitor,u"; title = "Move the workspace to the upper monitor"; }
  { key = "Super+Shift+Alt+Down"; action = "movecurrentworkspacetomonitor,d"; title = "Move the workspace to the lower monitor"; }
  { key = "Super+Shift+Ctrl+Left"; action = "movewindow,mon:l"; title = "Move the window to the left monitor"; }
  { key = "Super+Shift+Ctrl+Right"; action = "movewindow,mon:r"; title = "Move the window to the right monitor"; }
  { key = "Super+Shift+Ctrl+Up"; action = "movewindow,mon:u"; title = "Move the window to the upper monitor"; }
  { key = "Super+Shift+Ctrl+Down"; action = "movewindow,mon:d"; title = "Move the window to the lower monitor"; }

  # ── Resize ───────────────────────────────────────────────────────────
  # The scrolling layout keeps a list of widths to cycle through, the way
  # niri keeps preset column widths.
  { key = "Super+minus"; action = "layoutmsg,colresize +conf"; title = "Widen the column"; }
  { key = "Super+equal"; action = "layoutmsg,colresize -conf"; title = "Narrow the column"; }

  # ── Applications ────────────────────────────────────────────────────
  { key = "Super+Return"; action = "exec,${terminal}"; title = "Terminal"; }
  { key = "Super+Shift+Return"; action = "exec,${browser}"; title = "Browser"; }
  { key = "Super+Shift+B"; action = "exec,${browser}"; title = "Browser"; }
  { key = "Super+Shift+F"; action = "exec,${fileManager}"; title = "File manager"; }
  { key = "Super+Shift+N"; action = "exec,${editor}"; title = "Editor"; }

  # ── Omarchy menu ────────────────────────────────────────────────────
  { key = "Super+Space"; action = "exec,${menu}"; title = "Omarchy menu"; }
  { key = "Super+Alt+Space"; action = "exec,${appsMenu}"; title = "Applications"; }
  { key = "Super+Escape"; action = "exec,${systemMenu}"; title = "System menu"; }
  { key = "Super+K"; action = "exec,${keybindings}"; title = "Keybindings"; }

  # ── Screenshots and screen capture ──────────────────────────────────
  { key = "Super+Print"; action = "exec,${hyprpicker} -a"; title = "Colour picker"; }

  # ── Session ─────────────────────────────────────────────────────────
  { key = "Super+Ctrl+L"; action = "exec,${swaylock}"; title = "Lock the screen"; }
  { key = "XF86PowerOff"; action = "exec,${systemMenu}"; title = "Power menu"; props = "l"; }

  # ── Audio, brightness and media ─────────────────────────────────────
  {
    key = "XF86AudioRaiseVolume";
    action = "exec,${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0";
    title = "Volume up";
    props = "l";
  }
  {
    key = "XF86AudioLowerVolume";
    action = "exec,${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 0.1- -l 1.0";
    title = "Volume down";
    props = "l";
  }
  {
    key = "XF86AudioMute";
    action = "exec,${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
    title = "Mute";
    props = "l";
  }
  {
    key = "XF86AudioMicMute";
    action = "exec,${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
    title = "Mute the microphone";
    props = "l";
  }
  {
    key = "XF86MonBrightnessUp";
    action = "exec,${brightnessctl} set +10%";
    title = "Brightness up";
    props = "l";
  }
  {
    key = "XF86MonBrightnessDown";
    action = "exec,${brightnessctl} set 10%-";
    title = "Brightness down";
    props = "l";
  }
  {
    key = "XF86AudioPlay";
    action = "exec,${playerctl} play-pause";
    title = "Play or pause";
    props = "l";
  }
  {
    key = "XF86AudioNext";
    action = "exec,${playerctl} next";
    title = "Next track";
    props = "l";
  }
  {
    key = "XF86AudioPrev";
    action = "exec,${playerctl} previous";
    title = "Previous track";
    props = "l";
  }
]
++ workspaceBinds
++ workspaceMoveBinds

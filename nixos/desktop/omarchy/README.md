# Omarchy on niri

Omarchy is an opinionated desktop built around Hyprland. This is the same
desktop running on **niri**, a scrollable-tiling Wayland compositor, in
NixOS.

Two things had to change to get there:

1. **The compositor.** Hyprland's Lua configuration API and its IPC socket
   have no niri equivalent, so Omarchy's keybindings are ported by hand
   (`bindings.nix`) rather than translated.
2. **The portal.** niri does not implement the GlobalShortcuts portal, so
   applications that ask the desktop for a global hotkey get nothing here
   while they work on Hyprland, KDE Plasma 6 and GNOME 48. The compositor is
   forked in `pkgs/niri-global-shortcuts` to add it.

## What is here

| Path | What it does |
|---|---|
| `default.nix` | The NixOS module. `programs.omarchy.*` is the whole surface. |
| `bindings.nix` | Omarchy's keybindings, ported to niri actions. |
| `niri-config.nix` | Renders the niri configuration from the bindings and the theme. |
| `apps.nix` | The app catalogue, from Omarchy's Install menu. |
| `launcher.nix` | The menu, as a fuzzel launcher. |
| `terminal-theme.nix` | Renders the theme for foot, alacritty, kitty and ghostty. |
| `check-terminal-themes.sh` | Asks each terminal to read the rendered theme back. |
| `themes/` | Omarchy's colour palettes, vendored from upstream. |

## Enabling it

The laptop (`nixos/hosts/book3`) has it on:

```nix
programs.omarchy.enable = true;
```

Plasma is gated on the same switch (`nixos/desktop/kde.nix`), so setting it to
false brings the old desktop back.

The session shows up in the greeter as **Omarchy**. It is a separate package
from niri itself, because it points niri at `/etc/omarchy/niri.kdl` instead of
the user's own `~/.config/niri/config.kdl`.

Local overrides go in `~/.config/niri/overrides.kdl`. The generated file
includes it last, so it wins.

## The GlobalShortcuts portal

This is the part that is not in upstream niri.

An application registers a global hotkey by calling
`org.freedesktop.portal.GlobalShortcuts` on the session bus.
xdg-desktop-portal implements that interface and forwards to the compositor's
`org.freedesktop.impl.portal.GlobalShortcuts`. Hyprland, KDE and GNOME
implement the compositor side; before this fork, niri did not.

The fork implements it the way KDE does: the compositor owns the bus name
`org.freedesktop.impl.portal.desktop.niri`, serves the interface at
`/org/freedesktop/portal/desktop`, and binds the key itself when the
application asks for one.

The pieces:

- `pkgs/niri-global-shortcuts/patches/` — four patches against niri `v26.04`,
  one per commit. The same branch is on the fork at
  [rbelem/niri](https://github.com/rbelem/niri/tree/feature/global-shortcuts).
- `share/xdg-desktop-portal/portals/niri.portal` — the backend declaration,
  installed by the package. The file name is the backend name, so it has to be
  `niri.portal` and not something else.
- `xdg.portal.config.niri` in the module — names niri as the backend for
  `org.freedesktop.impl.portal.GlobalShortcuts`, which is what makes
  xdg-desktop-portal route to it.

The application sends its preferred trigger in the XDG shortcuts-spec format
(`CTRL+ALT+T`, `SUPER+space`, `F8`). niri parses it, refuses it if it collides
with one of the user's own keybindings or if it would swallow plain typing,
and otherwise binds it. Pressing the key emits `Activated` on the portal
interface.

The fork also answers the two questions a desktop has to answer about a
shortcut it did not ask for: a combination that another session already holds
is refused, and the shortcut is left out of the results, and a combination
that would take a plain key is refused unless it carries Ctrl, Alt or Super.

Known limits of the fork:

- The binding is not remembered across restarts. The application has to
  register it again.
- There is no UI to rebind a shortcut. The application gets the trigger it
  asked for, or nothing.
- The state lives in the compositor's memory, so a shortcut registered by an
  application that has since exited stays registered until niri restarts.
- The keyboard-shortcuts-inhibit protocol does not cover these shortcuts.
  An application that grabs the keyboard shortcuts does not stop a global
  shortcut from firing, because the application asked for a global shortcut
  in the first place.

## What did not come across

Omarchy's bar and menu are a QuickShell application. That shell imports
`Quickshell.Hyprland` and talks to Hyprland over its IPC socket, and there is
no niri equivalent of that module. Porting it means writing a niri backend for
Quickshell, which is a project of its own. So:

- The **menu** is a fuzzel launcher (`launcher.nix`) with a subset of Omarchy's
  entries: applications, the system menu, the keybindings and two links. The
  entries whose action is an Omarchy command that has no niri counterpart
  (install, remove, update, the QuickShell panels) are not there.
- The **bar** is niri's own overview.

The following Omarchy features have no niri equivalent and were left out of
the binding table:

| Omarchy | Why |
|---|---|
| Toggle window split | niri's scrolling layout has no split. |
| Pseudo window | niri has no pseudo windows. |
| Scratchpad (`SUPER+S`) | niri has no special workspaces, only named ones. |
| Window groups (`SUPER+G`) | niri has no groups. |
| Save and restore window width | niri has no per-window width memory. |
| Cycle workspace layout (`SUPER+L`) | niri's layout is not switchable that way. |
| Vertical window swap | niri scrolls sideways, so there is nothing to swap vertically. |
| Universal clipboard (`SUPER+C` and friends) | niri cannot inject keys into the focused client. |
| Input method switching | left to the input-method framework. |
| Notifications (`SUPER+comma`) | the portal notification daemon owns those. |
| Panels (`SUPER+CTRL+B` and friends) | the QuickShell panels have no niri counterpart. |
| Transparency and gap toggles | niri takes those from its own configuration. |

Two bindings were given a different meaning rather than dropped. Omarchy's
`SUPER+HOME` restores a saved window width, which niri cannot do, so it
focuses the first column instead, and `SUPER+END` focuses the last one.
Omarchy's `ALT+TAB` cycles through every window; niri has no such cycle, so
it toggles between the last two windows with `focus-window-previous`, and
`ALT+SHIFT+TAB` is not bound.

One behaviour is not portable at all. Omarchy's volume and brightness keys
repeat while they are held; niri has no bind property for repeating a
spawn, so those keys fire once per press.

## Themes

The theme is a colour palette, the same one Omarchy ships. It drives niri's
background and focus ring, and it is rendered into the format each terminal
expects.

The theme is applied by a user service that runs when the session starts. It
writes the colour file into the terminal's configuration directory, and it
writes a main configuration that loads the colours, but only when the user
has no main configuration of their own. An existing `~/.config/ghostty/config`
or `~/.config/kitty/kitty.conf` is never touched, so add the include line
yourself if you already have one:

```
# kitty
include themes/omarchy.conf
```

The application catalogue in `apps.nix` is what the launcher offers. A
command line program in the "Agents" category is started inside the terminal,
and the "Languages" category is installed but not offered in the launcher.

## Checking it

```sh
nix build .#checks.x86_64-linux.omarchy-desktop
```

That check asserts the fork ships the portal backend and the interface, that
the generated niri configuration parses with niri's own validator, that the
session is offered to the greeter, that the portal backend is the one
xdg-desktop-portal is told to prefer, and that foot, alacritty, kitty and
ghostty each read the rendered theme.

It is built on its own rather than through `nix flake check`, because that
command also builds the RT-AX88U packages, whose GPL source input is not
available in this checkout.

The decisions behind this work, and the evidence for each one, are in
`.audit/omarchy-niri.tsv` at the root of the repository.

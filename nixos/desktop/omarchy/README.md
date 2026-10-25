# Omarchy on Hyprland

Omarchy is an opinionated desktop built around Hyprland. This is the same
desktop in NixOS, on nixpkgs' Hyprland 0.56.2 with `general:layout = scrolling`:
a workspace is a tape of columns that scrolls sideways instead of shrinking
windows to fit another one. That is niri's model, and it is the model this
module ran on before the port back to Hyprland; the niri fork it used then
lives at [rbelem/niri](https://github.com/rbelem/niri).

No compositor fork is involved now. Hyprland's own portal backend ships the
GlobalShortcuts interface that niri lacks.

## What is here

| Path | What it does |
|---|---|
| `default.nix` | The NixOS module. `programs.omarchy.*` is the whole surface. |
| `shell.nix` | The shell fragment: OMARCHY_PATH, the packaged bin/ on PATH, and what the shell spawns by bare name. |
| `bindings.nix` | Omarchy's keybindings, as Hyprland dispatcher calls. |
| `hyprland-config.nix` | Renders `hyprland.lua` from the bindings and the theme. |
| `apps.nix` | The app catalogue, from Omarchy's Install menu. |
| `terminal-theme.nix` | Renders the theme for foot, alacritty, kitty and ghostty. |
| `check-terminal-themes.sh` | Asks each terminal to read the rendered theme back. |
| `sddm-theme/` | Omarchy's SDDM greeter theme, vendored from upstream. |
| `themes/` | Omarchy's colour palettes, vendored from upstream. |

The shell itself is `pkgs/omarchy-shell`: the upstream tree at the `omarchy`
flake input, copied whole into `$out/share/omarchy` (minus the authoring-only
dirs `.github`, `docs`, `manual`, `test` and `plans`), with `bin/` linked as
plain symlinks. Two patches, both with `--replace-fail` so upstream drift
fails the build instead of shipping stale text: the input-method watcher gets
a PATH-resolved `python3` instead of `/usr/bin/python3`, and app launching
uses `gtk-launch` directly instead of through `uwsm-app` (there is no uwsm
session here).

## Enabling it

The laptop (`nixos/hosts/book3`) has it on:

```nix
programs.omarchy.enable = true;
```

Plasma is gated on the same switch (`nixos/desktop/kde.nix`), so setting it to
false brings the old desktop back.

The session shows up in the greeter as **Omarchy**. It is a separate package
from Hyprland's own session, because it passes `/etc/omarchy/hyprland.lua` with
`--config` instead of letting Hyprland read `~/.config/hypr/hyprland.lua`.

Hyprland does not start `graphical-session.target` unless UWSM does, and this
module runs Hyprland without UWSM, so the generated configuration starts the
target with `exec-once`. That is what brings up the services Hyprland does
not start (`session.nix`): hyprpolkitagent for authentication prompts and
swayidle to lock the screen after five idle minutes and blank it after ten.
Notifications need no daemon: the shell draws them itself. The shell starts
with the compositor from the same handler (`omarchy-launch-shell`,
upstream's `default/hypr/autostart.lua` form): no systemd unit, because the
shell must not outlive the compositor.

The generated file is the whole configuration. There is no overrides include,
because Hyprland's `source` fails when the file is missing and a fresh account
has nothing to include. Change the module options, or add a `source` line of
your own.

To try it without touching the machine, `nixos-rebuild build-vm --flake
.#book3` builds a VM whose greeter is Omarchy's own SDDM theme. The VM-only
password is `nixos` for the `rodrigo` user; the real machine keeps no
password in the repo.

## The GlobalShortcuts portal

An application registers a global hotkey by calling
`org.freedesktop.portal.GlobalShortcuts` on the session bus.
xdg-desktop-portal implements that interface and forwards to the compositor's
`org.freedesktop.impl.portal.GlobalShortcuts`. niri does not implement the
compositor side, which is why this module used to carry a fork of it. Hyprland
does.

- `xdg-desktop-portal-hyprland` 1.4.1 installs
  `share/xdg-desktop-portal/portals/hyprland.portal`, which declares
  `org.freedesktop.impl.portal.GlobalShortcuts` and lists `Hyprland` under
  `UseIn`. `programs.hyprland` adds the package to `xdg.portal.extraPortals` and
  to `xdg.portal.configPackages`.
- `xdg.portal.config.hyprland` in the module pins the routing: GlobalShortcuts
  to `hyprland`, Access and Notification to `gtk`, Secret to `gnome-keyring`,
  and `hyprland;gtk` as the default. NixOS writes it to
  `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`, and `/etc/xdg` is read
  before the package's copy under `/run/current-system/sw`.

The session's `DesktopNames=Hyprland` is what makes xdg-desktop-portal pick that
file: it reads the first entry of `XDG_CURRENT_DESKTOP` and looks for
`$desktop-portals.conf`.

## What did not come across

Omarchy's bar, dock, menu, OSD, lock screen and notifications are upstream's
QuickShell shell, and this repository packages that shell whole. What stays
out is the pacman/update/AUR stack: the tree ships it, but there is no pacman
on NixOS, so those commands are vendored-but-unreachable. The menu's install,
remove and update routes offer Arch operations that cannot run here; nothing
is patched to pretend otherwise.

Two Arch-only reads degrade gracefully and are left as-is. The
`omarchy-platform` files (`/usr/share/omarchy-platform/audio.json` and
`display-cutouts.json`) have `onLoadFailed` handlers that fall back to no
hints. The `zone1970.tab` read feeds only the world-clock panel's fallback
coordinates. The `pacman -Q` guards in the menu model answer "missing" when
there is no database, which is the correct answer on NixOS.

The following bindings are left out of the table in `bindings.nix`:

| Omarchy | Why |
|---|---|
| Toggle window split | the scrolling layout has no split. |
| Pseudo window | the scrolling layout has no pseudo-tiling. |
| Scratchpad (`SUPER+S`) | not ported; it would be a special workspace. |
| Window groups (`SUPER+G`) | not ported. |
| Save and restore window width | not ported; Omarchy keeps that state in its own files. |
| Cycle workspace layout (`SUPER+L`) | the desktop is pinned to the scrolling layout. |
| Universal clipboard (`SUPER+C` and friends) | needs a clipboard manager, which the module does not install. |
| Input method switching | left to the input-method framework. |
| Notifications (`SUPER+comma`) | the shell draws them; the binding is not assigned. |
| Panels (`SUPER+CTRL+B` and friends) | the shell ships its panels, but no toggle binding is assigned. |
| Transparency and gap toggles | the layout takes both from its configuration. |
| Focus the first or last column (`SUPER+HOME`, `SUPER+END`) | the scrolling layout moves focus one column at a time. |
| Column height presets (`SUPER+SHIFT+minus`, `SUPER+SHIFT+equal`) | the scrolling layout has no per-window height presets. |
| Screenshots (`Print`, `SUPER+SHIFT+S`) | no screenshot tool is installed; Omarchy's is grim-based. |

A few bindings mean something slightly different. `SUPER+ALT+F` maximizes the
column by setting its width to the full workspace, and `SUPER+minus` and
`SUPER+equal` walk it back down the width list. `CTRL+ALT+TAB` and
`CTRL+ALT+SHIFT+TAB` step through monitors in order. `ALT+TAB` toggles between
the last two windows. The volume, brightness and media keys keep working while
the screen is locked, which is what the `l` bind flag in `bindings.nix` does.

## Themes

The theme is a colour palette, the same one Omarchy ships. It gives the windows
their border colours, and it is rendered into the format each terminal expects.

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

The application catalogue in `apps.nix` decides which packages land in the
user's PATH. The shell's own app library resolves their desktop entries
from there (via `gtk-launch`, after this port's `uwsm-app` patch).

## The menu bindings

`SUPER+Space`, `SUPER+ALT+Space` and `SUPER+Escape` summon the shell menu at
its `root`, `apps` and `system` routes, mirroring upstream
`default/hypr/bindings/utilities.lua`. `SUPER+K` runs the upstream
`omarchy-menu-keybindings` command, which renders inside the shell menu and
dispatches the chosen binding; the fuzzel list it replaced is deleted.

## Checking it

```sh
nix build .#checks.x86_64-linux.omarchy-desktop
```

That check asserts that the portal package ships the GlobalShortcuts backend,
that the generated configuration passes `Hyprland --verify-config`, that it is
the scrolling layout with the translated keybindings in it, that the session is
offered to the greeter, that the portal routes GlobalShortcuts to Hyprland, that
no reference to the retired niri fork is left, that foot, alacritty, kitty
and ghostty each read the rendered theme, that the shell package ships
`shell.qml`, and that the session autostarts `omarchy-launch-shell`.

## Theme staging for the shell

The same user service that writes the terminal colours also stages the
packaged theme where the shell reads it: the tree's `themes/<name>/` is
copied to `~/.local/state/omarchy/current/theme/` with
`--no-preserve=mode`, plus a `theme.name` file. The copy is never a symlink:
upstream treats a symlinked theme as user-owned and writes into it, and the
store is read-only.

One overlap is left for a follow-up. The shell carries its own idle lock
(ext-session-lock, 300 seconds in its defaults) next to this module's
swayidle plus swaylock, which locks at the same mark. Both engage; unlocking
takes two passes. The verified swaylock path stays until the idle handoff is
designed.

It is built on its own rather than through `nix flake check`, because that
command also builds the RT-AX88U packages, whose GPL source input is not
available in this checkout.

The decisions behind the niri version of this port, and the evidence for each,
are in `.audit/omarchy-niri.tsv` at the root of the repository.

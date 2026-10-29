# Why: modules/AGENTS.md#applications-available-through-the-omarchy-menu-as
{ ... }:
{
  programs.nixarchy.apps = {

  # ── Service ─────────────────────────────────────────────────────
    # _1password.enable = true;  #@ _1password  # unfree — Needs the module, not the package: unlocking requires a setuid helper that only programs._1password-gui installs. Set `settings.polkitPolicyOwners = [ "yourname" ]`. 
    #   _1password.settings = { };  #@ _1password.settings
    # bitwarden.enable = true;  #@ bitwarden
    # dropbox.enable = true;  #@ dropbox  # unfree
    # nordvpn.enable = true;  #@ nordvpn  # unfree
    # once.enable = true;  #@ once
    # signal.enable = true;  #@ signal
    # slack.enable = true;  #@ slack  # unfree
    # spotify.enable = true;  #@ spotify  # unfree

  # ── Utility ─────────────────────────────────────────────────────
    # aether.enable = true;  #@ aether
    # android-tools.enable = true;  #@ android-tools
    # freerdp.enable = true;  #@ freerdp  # A general RDP client for connecting to Windows or other RDP servers. For Hyprland-to-Hyprland remote desktop use gliff (Setup > Remote desktop > Connect with gliff).
    # omacalc.enable = true;  #@ omacalc
    # omacut.enable = true;  #@ omacut
    # omawrite.enable = true;  #@ omawrite
    # scrcpy.enable = true;  #@ scrcpy

  # ── Terminal ────────────────────────────────────────────────────
    # alacritty.enable = true;  #@ alacritty
    # foot.enable = true;  #@ foot
    # ghostty.enable = true;  #@ ghostty
    # kitty.enable = true;  #@ kitty

  # ── AI ──────────────────────────────────────────────────────────
    # antigravity.enable = true;  #@ antigravity  # unfree
    # chatgpt.enable = true;  #@ chatgpt  # unfree
    # claude-code.enable = true;  #@ claude-code  # unfree
    # codex.enable = true;  #@ codex
    # dictation.enable = true;  #@ dictation  # Hold F9 to dictate, or toggle with Super+Ctrl+X. Downloads a ~150 MB whisper model on first activation, into your own data directory rather than the store. `~/.config/voxtype/config.toml` is seeded once and is then yours to edit. 
    #   dictation.settings = { };  #@ dictation.settings
    # gemini-cli.enable = true;  #@ gemini-cli
    # hey-cli.enable = true;  #@ hey-cli
    # lm-studio.enable = true;  #@ lm-studio  # unfree
    # omarchy-voice.enable = true;  #@ omarchy-voice  # Speech into desktop actions. 7.2 GiB installed, most of it whisper and the Piper voice models. Desktop control, the wake word and notification logging each start off; turn on what you want in `programs.omarchy-voice`. 
    #   omarchy-voice.settings = { };  #@ omarchy-voice.settings
    # openclaw.enable = true;  #@ openclaw
    # opencode.enable = true;  #@ opencode
    # t3-code.enable = true;  #@ t3-code

  # ── Browser ─────────────────────────────────────────────────────
    # brave.enable = true;  #@ brave
    # chrome.enable = true;  #@ chrome  # unfree
    # edge.enable = true;  #@ edge  # unfree
    # firefox.enable = true;  #@ firefox  # A NixOS module, so policies and extensions are declarative too.
    #   firefox.settings = { };  #@ firefox.settings
    # zen.enable = true;  #@ zen

  # ── Development ─────────────────────────────────────────────────
    # bun.enable = true;  #@ bun
    # clojure.enable = true;  #@ clojure
    # deno.enable = true;  #@ deno
    # dotnet.enable = true;  #@ dotnet
    # elixir.enable = true;  #@ elixir
    # git-lfs.enable = true;  #@ git-lfs  # Installs git-lfs and writes the LFS filter config system-wide, so cloning an LFS repo just works.
    #   git-lfs.settings = { };  #@ git-lfs.settings
    # go.enable = true;  #@ go  # mise use --global go@latest downloads a toolchain outside Nix. This is nixpkgs' go, rebuilt with the system.
    # java.enable = true;  #@ java
    # nodejs.enable = true;  #@ nodejs  # mise' prebuilt Node is dynamically linked against paths NixOS does not have, so it often will not execute at all. This one does.
    # ocaml.enable = true;  #@ ocaml
    # php.enable = true;  #@ php
    # python.enable = true;  #@ python  # Already on the system as a runtime dependency of Omarchy's own scripts, so this row shows dim on a stock install. Select it to say so in your configuration rather than relying on that. 
    # rust.enable = true;  #@ rust  # rustup manages its own toolchains under ~/.rustup, the same as upstream. Use pkgs.cargo and pkgs.rustc instead if you would rather Nix pinned the compiler.
    # scala.enable = true;  #@ scala
    # symfony.enable = true;  #@ symfony  # unfree
    # uv.enable = true;  #@ uv  # Astral's Python package and project manager. `nixarchy dev init python` gives each project its own; this one is for everywhere else.
    # zig.enable = true;  #@ zig

  # ── Editor ──────────────────────────────────────────────────────
    # cursor.enable = true;  #@ cursor  # unfree
    # emacs.enable = true;  #@ emacs
    # helix.enable = true;  #@ helix
    # vim.enable = true;  #@ vim
    # vscode.enable = true;  #@ vscode  # unfree
    # zed.enable = true;  #@ zed

  # ── Gaming ──────────────────────────────────────────────────────
    # heroic.enable = true;  #@ heroic
    # lutris.enable = true;  #@ lutris
    # minecraft.enable = true;  #@ minecraft
    # retroarch.enable = true;  #@ retroarch  # Ships 13 free cores. For more -- including snes9x, genesis-plus-gx, mame and dolphin, which nixpkgs marks unfree -- set allowUnfree and override the package:   apps.retroarch.package =     pkgs.retroarch.withCores (c: [ c.snes9x c.mame c.dolphin ]); 
    # steam.enable = true;  #@ steam  # unfree — A module, not a package: Steam needs an FHS wrapper to run at all.
    #   steam.settings = { };  #@ steam.settings
    # xbox-controllers.enable = true;  #@ xbox-controllers  # A kernel driver, so it is a hardware option rather than a package.
    #   xbox-controllers.settings = { };  #@ xbox-controllers.settings

  # ── Preinstalls ─────────────────────────────────────────────────
    # obsidian.enable = true;  #@ obsidian  # unfree — Preinstalled upstream, opt-in here because it is unfree. Theme syncing needs the Omarchy theme selected under Appearance > Themes in the app; omarchy-theme-set-obsidian writes it on every theme change. 
  };
}

# Offered by the Omarchy menu but with no nixpkgs equivalent:
#   Brave Origin — Brave's managed build is AUR-only with no published source; enable apps.brave and put policies in /etc/brave/policies/managed, which stock Brave honours identically.
#   Grok Bot — Removed from nixarchy: an unfree Electron build pinned to a Cursor CDN commit with no update path.
#   Sublime Text — nixpkgs marks sublimetext4 broken over an insecure OpenSSL dependency; enabling it fails the rebuild.

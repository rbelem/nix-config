# The apps the Omarchy desktop can install, mapped to nixpkgs.
#
# The list follows Omarchy's own Install menu (default/omarchy/omarchy-menu.jsonc
# upstream), trimmed to the apps that exist in nixpkgs. Omarchy ships its menu
# as a QuickShell application that talks to Hyprland over its IPC; this port
# keeps the catalogue declarative instead, so an app is a line of Nix and the
# launcher reads the same set.
#
# Per-app fields:
#   label    Shown in the launcher.
#   category Groups rows in the launcher, and decides how an app is started:
#            a command line program in the "Agents" or "Languages" category
#            runs inside the terminal, everything else runs on its own, and
#            the "Languages" category is installed but not offered in the
#            launcher at all.
#   package  nixpkgs attribute. Installed into the user's PATH when enabled.
{
  # ── Browsers ────────────────────────────────────────────────────────────
  brave = { label = "Brave"; category = "Browser"; package = "brave"; };
  chrome = { label = "Chrome"; category = "Browser"; package = "google-chrome"; };
  edge = { label = "Edge"; category = "Browser"; package = "microsoft-edge"; };
  firefox = { label = "Firefox"; category = "Browser"; package = "firefox"; };

  # ── Editors ─────────────────────────────────────────────────────────────
  vscode = { label = "VS Code"; category = "Editor"; package = "vscode"; };
  cursor = { label = "Cursor"; category = "Editor"; package = "code-cursor"; };
  zed = { label = "Zed"; category = "Editor"; package = "zed-editor"; };
  helix = { label = "Helix"; category = "Editor"; package = "helix"; };
  emacs = { label = "Emacs"; category = "Editor"; package = "emacs"; };
  vim = { label = "Vim"; category = "Editor"; package = "vim"; };
  sublime = { label = "Sublime Text"; category = "Editor"; package = "sublime4"; };

  # ── Terminals ───────────────────────────────────────────────────────────
  foot = { label = "Foot"; category = "Terminal"; package = "foot"; };
  alacritty = { label = "Alacritty"; category = "Terminal"; package = "alacritty"; };
  ghostty = { label = "Ghostty"; category = "Terminal"; package = "ghostty"; };
  kitty = { label = "Kitty"; category = "Terminal"; package = "kitty"; };

  # ── Communication ───────────────────────────────────────────────────────
  signal = { label = "Signal"; category = "Chat"; package = "signal-desktop"; };
  slack = { label = "Slack"; category = "Chat"; package = "slack"; };
  discord = { label = "Discord"; category = "Chat"; package = "discord"; };

  # ── Media ───────────────────────────────────────────────────────────────
  spotify = { label = "Spotify"; category = "Media"; package = "spotify"; };
  obsidian = { label = "Obsidian"; category = "Notes"; package = "obsidian"; };

  # ── Games ───────────────────────────────────────────────────────────────
  steam = { label = "Steam"; category = "Games"; package = "steam"; };
  lutris = { label = "Lutris"; category = "Games"; package = "lutris"; };
  heroic = { label = "Heroic"; category = "Games"; package = "heroic"; };
  retroarch = { label = "RetroArch"; category = "Games"; package = "retroarch"; };

  # ── Security and network ────────────────────────────────────────────────
  bitwarden = { label = "Bitwarden"; category = "Utilities"; package = "bitwarden-desktop"; };
  nordvpn = { label = "NordVPN"; category = "Utilities"; package = "nordvpn"; };

  # ── Agent tooling ───────────────────────────────────────────────────────
  claude-code = { label = "Claude Code"; category = "Agents"; package = "claude-code"; };
  codex = { label = "Codex"; category = "Agents"; package = "codex"; };
  opencode = { label = "OpenCode"; category = "Agents"; package = "opencode"; };
  gemini-cli = { label = "Gemini CLI"; category = "Agents"; package = "gemini-cli"; };

  # ── Languages ───────────────────────────────────────────────────────────
  go = { label = "Go"; category = "Languages"; package = "go"; };
  rust = { label = "Rust"; category = "Languages"; package = "rustc"; };
  nodejs = { label = "Node.js"; category = "Languages"; package = "nodejs"; };
  bun = { label = "Bun"; category = "Languages"; package = "bun"; };
  deno = { label = "Deno"; category = "Languages"; package = "deno"; };
  java = { label = "Java"; category = "Languages"; package = "openjdk"; };
  elixir = { label = "Elixir"; category = "Languages"; package = "elixir"; };
  zig = { label = "Zig"; category = "Languages"; package = "zig"; };
  clojure = { label = "Clojure"; category = "Languages"; package = "clojure"; };
  scala = { label = "Scala"; category = "Languages"; package = "scala"; };
  dotnet = { label = ".NET"; category = "Languages"; package = "dotnet-sdk"; };
  python = { label = "Python"; category = "Languages"; package = "python3"; };
  ocaml = { label = "OCaml"; category = "Languages"; package = "ocaml"; };
}

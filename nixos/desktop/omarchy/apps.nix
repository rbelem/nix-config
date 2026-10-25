# The apps the Omarchy desktop can install, mapped to nixpkgs.
#
# The list follows Omarchy's own Install menu (default/omarchy/omarchy-menu.jsonc
# upstream), trimmed to the apps that exist in nixpkgs. An app is a line of
# Nix: enabling it installs its package into the user's PATH, and the shell's
# own app library finds the desktop entry from there.
#
# install-menu.nix turns this file into the commands a user drives it with, so
# an id here is also what omarchy-apps-toggle and omarchy-apps-search take.
#
# Per-app fields:
#   label    The catalogue name.
#   category Informational grouping, kept from the upstream Install menu.
#   package  nixpkgs attribute. Installed into the user's PATH when enabled.
{
  # ── Browsers ────────────────────────────────────────────────────────────
  brave = { label = "Brave"; category = "Browser"; package = "brave"; };
  brave-origin = { label = "Brave Origin"; category = "Browser"; package = "brave-origin"; };
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

  # ── Security, network and storage ───────────────────────────────────────
  # Upstream's id is 1password, spelled out here because the id is also an
  # attribute name in the declaration file.
  onepassword = { label = "1Password"; category = "Utilities"; package = "_1password-gui"; };
  bitwarden = { label = "Bitwarden"; category = "Utilities"; package = "bitwarden-desktop"; };
  nordvpn = { label = "NordVPN"; category = "Utilities"; package = "nordvpn"; };
  dropbox = { label = "Dropbox"; category = "Utilities"; package = "dropbox"; };

  # ── Local AI ────────────────────────────────────────────────────────────
  lm-studio = { label = "LM Studio"; category = "AI"; package = "lmstudio"; };
  ollama = { label = "Ollama"; category = "AI"; package = "ollama"; };

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
  php = { label = "PHP"; category = "Languages"; package = "php"; };
  laravel = { label = "Laravel"; category = "Languages"; package = "laravel"; };
  symfony = { label = "Symfony"; category = "Languages"; package = "symfony-cli"; };
}

# Upstream's Install menu also offers these. They are absent because nixpkgs
# cannot install them as a package, so any attribute would be a guess:
#
#   no nixpkgs attribute: Zen, Perplexity, Claude Desktop, Grok Bot,
#     Hermes Desktop, ONCE, Battle.net
#   macOS only: ChatGPT Desktop (nixpkgs' chatgpt)
#   kernel module, not a package: Xbox controllers (xpadneo)
#   flatpak or web app: GeForce NOW, Xbox Cloud Gaming, Microsoft 365
#   AppImage: T3 Code
#   removed from nixpkgs: Minecraft
#   marked insecure: OpenClaw
#   a service, not an app: Tailscale (services.tailscale is the install)
#   mise installers, not packages: Ruby on Rails, Phoenix, Docker DBs

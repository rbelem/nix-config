# Per-application configuration: what the packaged Omarchy tree ships for each
# application, planted in the user's home the way Omarchy's own provisioning
# plants it.
#
# Three kinds of artifact live here, and each has its own rule:
#
#   * The application's own configuration, copied once. An edited tmux.conf or
#     starship.toml is the user's, so a copy is made only where there is no
#     file yet, and the next login leaves it alone.
#   * The colour files that follow programs.omarchy.theme. These are rendered
#     from the same colors.toml terminal-theme.nix reads, and rewritten on
#     every login, because they are generated rather than written. A runtime
#     `omarchy-theme-switch` (theme.nix) moves the staged theme and the terminal
#     palettes but not these two; like the wallpaper and the GTK keys, they take
#     programs.omarchy.theme, which is what the next login applies.
#   * Neovim's colourscheme, which is per theme rather than derived from the
#     palette (catppuccin ships a spec naming catppuccin-mocha), so it is a
#     link into the theme directory the theme service stages.
#
# Upstream's omarchy-provision-user links the tree's agent skills into every
# agent's skill directory; that lands here as links, kept current the same way
# the Neovim link is.
#
# A module rather than a fragment, so it reads programs.omarchy itself and
# default.nix gains it with one import line.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  tree = "${pkgs.omarchy-shell}/share/omarchy";

  theme = builtins.fromTOML (builtins.readFile ./themes/${cfg.theme}/colors.toml);

  # Application directories under the tree's config/, each of which becomes the
  # user's own directory of that name. The whole directory is copied, so a file
  # upstream adds inside one arrives without an edit here:
  #
  #   btop      btop.conf, which asks for a theme named "current" (rendered below)
  #   fcitx5    the Super+I trigger keys, and Pinyin kept offline
  #   imv       the Ctrl-key edit, trash and rotate bindings
  #   lazygit   ships empty on purpose; upstream refreshes it as a placeholder
  #   opencode  theme = "system" and autoupdate = false
  #   tmux      prefix C-Space, the pane and copy-mode bindings
  seedApps = [
    "btop"
    "fcitx5"
    "imv"
    "lazygit"
    "opencode"
    "tmux"
  ];

  # The tree's own agent skills, linked into each home below. They cover the
  # shell, building an app for it, and diagnosing a crash; omarchy-agent-crash
  # reads one of them by path.
  agentSkills = [
    "diagnose-crash"
    "omarchy"
    "omarchy-app"
  ];

  # Every skill directory upstream's omarchy-provision-user writes to, including
  # the six from the migration that added the last skill (1790702606). Opencode
  # reads ~/.agents/skills, so it needs no entry of its own.
  skillHomes = [
    ".agents/skills"
    ".claude/skills"
    ".codex/skills"
    ".gemini/config/skills"
    ".hermes/skills"
    ".pi/agent/skills"
  ];

  # Upstream renders these with omarchy-theme-set-templates, a bash script with
  # a template language of its own. What these two files use is one form,
  # {{ key }}, and the guard turns anything else into a failed build rather
  # than a colour file with template text left in it.
  render =
    template:
    let
      rendered = lib.replaceStrings
        (map (key: "{{ ${key} }}") (builtins.attrNames theme))
        (map (key: theme.${key}) (builtins.attrNames theme))
        (builtins.readFile template);
    in
    if lib.hasInfix "{{" rendered then
      throw "appconfigs.nix: ${toString template} uses a template token this module cannot render"
    else
      rendered;

  # btop.conf asks for a theme by the name "current" and reads it from its own
  # themes directory; fcitx5 keeps the popup's colours in a theme directory.
  btopTheme = pkgs.writeText "omarchy-btop-theme" (render "${tree}/default/themed/btop.theme.tpl");
  fcitx5Theme = pkgs.writeText "omarchy-fcitx5-theme" (render "${tree}/default/themed/fcitx5-theme.conf.tpl");

  # The sources are a pinned package, so one that has moved is a bump that needs
  # this file edited. Assertions say so at build time instead of failing a login.
  # They are declared inside `config` below, not as a top-level assert: forcing
  # `pkgs` while the module arguments are still being applied is a recursion.
  absent = lib.filter (path: !builtins.pathExists path) (
    map (app: "${tree}/config/${app}") seedApps
    ++ map (skill: "${tree}/default/agents/skills/${skill}") agentSkills
  );
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = absent == [ ];
        message = "appconfigs.nix: the packaged tree does not ship ${lib.concatStringsSep " " absent}";
      }
    ];

    # A user service, like the theme one: what it writes is the user's home, and
    # it has to run after that service stages the theme directory the Neovim
    # link points into.
    systemd.user.services.omarchy-app-configs = {
      description = "Plant Omarchy's per-application configuration";
      wantedBy = [ "graphical-session.target" ];
      after = [ "omarchy-theme.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = ''
        set -eu
        config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
        state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"

        # Missing files only: a file the user has edited is theirs, so a second
        # run copies nothing. --no-preserve=mode because the source is a store
        # path and the copy has to stay writable.
        for app in ${lib.concatStringsSep " " seedApps}; do
          mkdir -p "$config_home/$app"
          cp -r --update=none --no-preserve=mode "${tree}/config/$app"/. "$config_home/$app"/
        done

        # starship is one file at the top of the config home rather than a
        # directory of its own, and it is the prompt the shell reads by name.
        if [ ! -e "$config_home/starship.toml" ]; then
          install -D -m 644 ${tree}/config/starship.toml "$config_home/starship.toml"
        fi

        # The generated colour files, rewritten every time: a theme artifact is
        # this module's, not the user's.
        install -D -m 644 ${btopTheme} "$config_home/btop/themes/current.theme"
        install -D -m 644 ${fcitx5Theme} "$data_home/fcitx5/themes/omarchy/theme.conf"

        # Point fcitx5 at that theme, the way omarchy-theme-set-fcitx5 does when
        # it activates one. A value the user set is kept, and "default" counts
        # as unset: fcitx5's own configtool writes it on any save, including a
        # save that only changed the font.
        classicui="$config_home/fcitx5/conf/classicui.conf"
        mkdir -p "$(dirname "$classicui")"
        touch "$classicui"
        for key in Theme DarkTheme; do
          value=$(sed -n "s/^$key=//p" "$classicui" | tail -n 1)
          if [ -z "$value" ]; then
            printf '%s\n' "$key=omarchy" >> "$classicui"
          elif [ "$value" = default ] || [ "$value" = default-dark ]; then
            sed "s/^$key=.*/$key=omarchy/" "$classicui" > "$classicui.omarchy-tmp"
            mv "$classicui.omarchy-tmp" "$classicui"
          fi
        done

        # The theme's page and menu glyphs are images resolved inside its own
        # directory. Upstream copies them from the distro's packaged fcitx5
        # theme; on NixOS that directory exists only where fcitx5 is installed,
        # which is exactly when a popup needs it.
        if fcitx5=$(command -v fcitx5); then
          packaged="$(dirname "$(dirname "$(readlink -f "$fcitx5")")")/share/fcitx5/themes/default"
          for glyph in "$packaged"/*.svg; do
            if [ -e "$glyph" ]; then
              ln -sfn "$glyph" "$data_home/fcitx5/themes/omarchy/''${glyph##*/}"
            fi
          done
        fi

        # Neovim's colourscheme: one file, pointing at the theme the service
        # above staged. Refreshed while it is still a link, because a theme
        # switch moves its target; a theme.lua somebody wrote is theirs, and
        # saying so is the difference between kept and silently ignored.
        nvim_link="$config_home/nvim/lua/plugins/theme.lua"
        if [ ! -e "$nvim_link" ] || [ -L "$nvim_link" ]; then
          mkdir -p "$(dirname "$nvim_link")"
          ln -sfn "$state_home/omarchy/current/theme/neovim.lua" "$nvim_link"
        else
          echo "omarchy: kept your $nvim_link, so Omarchy themes will not drive Neovim" >&2
        fi

        # The agent skills, in every home upstream links them into. A directory
        # of the user's own under one of those names is left where it is.
        for home in ${lib.concatStringsSep " " skillHomes}; do
          mkdir -p "$HOME/$home"
          for skill in ${lib.concatStringsSep " " agentSkills}; do
            link="$HOME/$home/$skill"
            if [ -e "$link" ] && [ ! -L "$link" ]; then
              echo "omarchy: kept your $link, so that skill is yours" >&2
            else
              ln -sfn "${tree}/default/agents/skills/$skill" "$link"
            fi
          done
        done
      '';
    };
  };
}

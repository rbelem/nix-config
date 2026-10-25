# The GUI install flow, as three commands over one declaration file.
#
# Omarchy's Install menu runs pacman. There is no pacman on NixOS, so the flow
# is a declaration instead: omarchy-apps-toggle switches an app in
# ~/.config/omarchy/apps.nix, omarchy-apps-apply copies that file here as
# apps.local.nix, and the next rebuild installs what it declares. The three
# verbs live in one file so they cannot disagree about where the state lives.
#
# apps.local.nix is generated, and the import below is conditional because the
# flake has to evaluate before the first toggle has written it.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  inherit (lib) mkIf mkOption types;

  catalogue = import ./apps.nix;

  declaration = "\${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/apps.nix";

  # Relative to the checkout named by programs.omarchy.appsRepo.
  relTarget = "nixos/desktop/omarchy/apps.local.nix";

  # One line per app: id, label, nixpkgs attribute. Built from the catalogue,
  # so a search can never offer an app the module cannot install.
  table = pkgs.writeText "omarchy-apps.tsv"
    (lib.concatStringsSep "\n"
      (lib.mapAttrsToList
        (id: app: lib.concatStringsSep "\t" [ id app.label app.package ])
        catalogue) + "\n");

  header = ''
    # Omarchy apps for this machine.
    #
    # omarchy-apps-search <query>   find an app by label, id or nixpkgs attribute
    # omarchy-apps-toggle <id>      switch one app on or off
    # omarchy-apps-apply            copy this file into the flake, then rebuild
    #
  '';

  search = pkgs.writeShellApplication {
    name = "omarchy-apps-search";
    runtimeInputs = [ pkgs.gawk pkgs.gnugrep ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "usage: omarchy-apps-search <query>" >&2
        exit 2
      fi

      if ! matches=$(grep -iF -- "$*" ${table}); then
        echo "no app matches '$*'" >&2
        exit 1
      fi

      printf '%s\n' "$matches" | awk -F'\t' '{ printf "  %-14s %-16s %s\n", $1, $2, $3 }'
    '';
  };

  toggle = pkgs.writeShellApplication {
    name = "omarchy-apps-toggle";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.gnused ];
    text = ''
      if [ $# -ne 1 ]; then
        echo "usage: omarchy-apps-toggle <app>" >&2
        exit 2
      fi

      app=$1
      if ! cut -f1 ${table} | grep -qxF -- "$app"; then
        echo "no app named '$app'; try omarchy-apps-search <query>" >&2
        exit 1
      fi

      file=${declaration}
      mkdir -p "$(dirname "$file")"

      if [ ! -f "$file" ]; then
        {
          printf '%s\n' ${lib.escapeShellArg header}
          printf '{ ... }:\n\n{\n'
          cut -f1 ${table} | sed 's|^|  # programs.omarchy.apps.|; s|$|.enable = true;|'
          printf '}\n'
        } > "$file"
      fi

      on="  programs.omarchy.apps.$app.enable = true;"
      off="  # programs.omarchy.apps.$app.enable = true;"

      line=$(grep -nxFm1 -- "$off" "$file" | cut -d: -f1) || true
      if [ -n "$line" ]; then
        sed -i "''${line}s|.*|$on|" "$file"
        echo "$app: on (omarchy-apps-apply installs it)"
        exit 0
      fi

      line=$(grep -nxFm1 -- "$on" "$file" | cut -d: -f1) || true
      if [ -n "$line" ]; then
        sed -i "''${line}s|.*|$off|" "$file"
        echo "$app: off (omarchy-apps-apply removes it)"
        exit 0
      fi

      # A hand-edited file can lose the line. Put it back inside the attribute
      # set rather than failing, since the toggle is the only sane repair here.
      line=$(grep -nxF -- '}' "$file" | cut -d: -f1 | tail -n1) || true
      if [ -z "$line" ]; then
        echo "$file has no closing brace; delete it to regenerate it" >&2
        exit 1
      fi
      sed -i "''${line}s|^|$on\\n|" "$file"
      echo "$app: on (omarchy-apps-apply installs it)"
    '';
  };

  apply = pkgs.writeShellApplication {
    name = "omarchy-apps-apply";
    runtimeInputs = [ pkgs.coreutils pkgs.diffutils pkgs.git pkgs.nix ];
    text = ''
      file=${declaration}
      if [ ! -f "$file" ]; then
        echo "no declarations at $file; run omarchy-apps-toggle <app> first" >&2
        exit 1
      fi

      # A declaration that does not parse breaks the eval of the rebuild, which
      # happens after this command has exited and cannot be asked about it.
      if ! nix-instantiate --parse "$file" > /dev/null; then
        echo "$file is not valid Nix; fix it before applying" >&2
        exit 1
      fi

      repo=${lib.escapeShellArg cfg.appsRepo}
      target="$repo/${relTarget}"

      echo "$(grep -c '^  programs\.omarchy\.apps\.[a-z0-9-]*\.enable = true;$' "$file") apps declared"

      if [ -f "$target" ] && cmp -s "$file" "$target"; then
        echo "${relTarget} is already up to date"
      else
        install -D -m644 "$file" "$target.tmp"
        mv -f "$target.tmp" "$target"
        echo "wrote ${relTarget}"
      fi

      # The flake reads the git tree, where an untracked file does not exist.
      # An intent-to-add entry makes the file part of the source without
      # staging content.
      if ! git -C "$repo" add --intent-to-add -- "$target"; then
        echo "could not add ${relTarget} to the git index; the flake will not see it" >&2
        exit 1
      fi

      echo "rebuild with: sudo nixos-rebuild switch --flake ${cfg.appsRepo}#${config.networking.hostName}"
    '';
  };
in
{
  imports = lib.optional (builtins.pathExists ./apps.local.nix) ./apps.local.nix;

  options.programs.omarchy.appsRepo = mkOption {
    type = types.str;
    default = "/home/rodrigo/Workspace/github.com/rbelem/nix-config";
    description = ''
      The checkout omarchy-apps-apply writes nixos/desktop/omarchy/apps.local.nix
      into, and the flake ref the rebuild command it prints names. It has to be
      the working copy: the rebuild reads the declaration from the git tree.
    '';
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ search toggle apply ];
  };
}

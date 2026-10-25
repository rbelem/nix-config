# What the vendored Omarchy installers expect from pacman/yay, shimmed.
#
# Upstream's installer verbs (omarchy-pkg-add/-install, the menu plugin's
# Install rows, omarchy-dev-pkg-test, the update flow's omarchy-update-pacman)
# are written for Arch: they run `pacman` to search, install and query, and
# `yay` for the AUR. Neither exists on NixOS, so with no shim every such verb
# dies with "pacman: command not found", which a user cannot tell apart from
# a broken PATH.
#
# None of the shims pretend to succeed.
#
# - A query (`pacman -Q|--query`, the shape omarchy-pkg-present/-missing use
#   for their presence checks) answers "not found": honest, since on NixOS
#   nothing is tracked by pacman's database; the check therefore reports the
#   packages it looks for as absent, which is what a no-op pacman would too.
#   That is the semantics we want even for packages the user really has,
#   because the NixOS-native check "is it in environment.systemPackages or a
#   manifest like programs.omarchy.flatpaks.apps?" is the module's job, not
#   pacman's.
# - Everything else (installs, syncs, removals, anything yay) exits 1 with
#   the message naming the NixOS-native equivalent, because silently
#   no-oping an install verb would be a lie.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  pacmanShim = pkgs.writeShellScript "omarchy-shim-pacman" ''
    # Presence checks redirect everything anyway (`pacman -Q -- x &>/dev/null`),
    # so the query path needs nothing but the right exit code and one note for
    # the callers that let stderr through.
    for arg in "$@"; do
      case $arg in
        -Q* | --query)
          echo "pacman shim: nothing is tracked by pacman on NixOS; treated as not found" >&2
          exit 1 ;;
      esac
    done

    cat >&2 <<'EOF'
omarchy shim: this command would drive pacman, which NixOS does not ship.
On NixOS, packages come from the configuration, not a package database:

  declarative (the right answer)   edit this repo's nixos config, e.g.
                                   environment.systemPackages,
                                   programs.omarchy.flatpaks.apps, etc.
  imperative, one profile           nix profile install nixpkgs#<name>
  temporary shell                   nix shell / nix-shell -p <name>

Search what natives have: https://search.nixos.org
EOF
    exit 1
  '';

  yayShim = pkgs.writeShellScript "omarchy-shim-yay" ''
    cat >&2 <<'EOF'
omarchy shim: yay drives the AUR, which NixOS does not ship.
Find the equivalent package first (nixpkgs covers most of the AUR's most
wanted), then declare it as above for pacman. When there is genuinely no
nixpkgs equivalent, build it from source in the repo (pkgs/ here) instead
of installing a second package manager.
Search: https://search.nixos.org
EOF
    exit 1
  '';

  shims = pkgs.buildEnv {
    name = "omarchy-nixos-pkg-shims";
    paths = [
      (pkgs.runCommand "omarchy-shim-pacman-bin" { } ''
        install -Dm555 ${pacmanShim} $out/bin/pacman
      '')
      (pkgs.runCommand "omarchy-shim-yay-bin" { } ''
        install -Dm555 ${yayShim} $out/bin/yay
      '')
    ];
  };
in
{
  options = { };

  config = lib.mkIf cfg.enable {
    # No real pacman/yay exists to collide with, and the profile is the one
    # SDDM's FacesDir shares, so a wrapper on PATH reaches every user,
    # including the ones the login flow spawns.
    environment.systemPackages = [ shims ];
  };
}

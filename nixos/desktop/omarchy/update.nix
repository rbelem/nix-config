# Updating the desktop, and asking whether there is anything to update.
#
# A flake update is two steps: move flake.lock, then rebuild from it. Done by
# hand they get out of order (rebuild first, and the switch builds the old
# inputs), or the rebuild is run over a half-finished edit. `omarchy-update` is
# that sequence with the two guards that matter: it refuses to start on a dirty
# checkout, and it says how to undo each half when the switch fails.
#
# Neither command stashes, resets or reverts anything, and flake.lock is the
# only file either one writes. The checkout is clean when an update starts, so
# `git restore flake.lock` is always the whole undo for the inputs, and
# `nixos-rebuild switch --rollback` is always the undo for the system. Both are
# printed in `omarchy-update --help` and again when the switch fails.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  inherit (lib) mkIf;

  # The checkout this module is rebuilt from. appsRepo already names it (see
  # install-menu.nix); a second option with the same default would only let the
  # two drift apart.
  repo = cfg.appsRepo;

  flakeRef = "${repo}#${config.networking.hostName}";

  # Both commands compare a lock file against a freshly resolved one, so both
  # carry the same summary: one "name<TAB>pin" line per pinned input, where the
  # pin is the first 12 characters of the rev. A path input has no rev, so its
  # narHash stands in; nodes with neither (a path inside another flake's own
  # lock) are not pins of this flake and are left out.
  lockdiff = ''
    pins() {
      jq -r '.nodes | to_entries[]
        | .value.locked as $l
        | select($l.rev != null or $l.narHash != null)
        | "\(.key)\t\(($l.rev // $l.narHash)[0:12])"' "$1" | sort
    }

    moves() {
      join -t $'\t' -a1 -a2 -e '(none)' -o 0,1.2,2.2 <(pins "$1") <(pins "$2") \
        | awk -F'\t' '$2 != $3 { printf "  %-14s %s -> %s\n", $1, $2, $3 }'
    }
  '';

  # The switch runs as root: a root shell runs it directly, a user's shell goes
  # through sudo. nixos-rebuild itself comes from PATH, so it is the running
  # system's copy rather than this flake's.
  root = ''
    root() {
      if [ "$(id -u)" -eq 0 ]; then
        "$@"
      else
        sudo "$@"
      fi
    }
  '';

  update = pkgs.writeShellApplication {
    name = "omarchy-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.jq
      pkgs.nix
    ];
    text = ''
      export LC_ALL=C

      repo=${lib.escapeShellArg repo}
      flake_ref=${lib.escapeShellArg flakeRef}

      usage() {
        cat <<TXT
      omarchy-update: move this flake's inputs, then switch to the rebuilt system.

      It refuses to start unless the checkout is clean, and it never stashes,
      resets or reverts anything: flake.lock is the only file it writes.

        checkout: $repo
        switch:   $flake_ref

        inputs back to the ones that built the running system:
          git -C $repo restore flake.lock
          sudo nixos-rebuild switch --flake $flake_ref

        the switch itself, back one generation:
          sudo nixos-rebuild switch --rollback
          sudo nixos-rebuild list-generations
      TXT
      }

      ${lockdiff}

      ${root}

      if [ "$#" -gt 0 ]; then
        case "$1" in
          -h | --help)
            usage
            exit 0
            ;;
          *)
            echo "omarchy-update: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
        esac
      fi

      if ! git -C "$repo" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "omarchy-update: $repo is not a git work tree" >&2
        exit 2
      fi

      dirty=$(git -C "$repo" status --porcelain)
      if [ -n "$dirty" ]; then
        echo "omarchy-update: refusing to update: $repo has uncommitted changes" >&2
        printf '%s\n' "$dirty" >&2
        echo "commit or discard them first; this command never stashes or resets" >&2
        exit 1
      fi

      # The system's own nixos-rebuild, not one from this flake's nixpkgs: the
      # running system is what drives the switch. Checked before the lock is
      # touched so a stripped PATH does not cost an update.
      if ! command -v nixos-rebuild > /dev/null 2>&1; then
        echo "omarchy-update: nixos-rebuild is not on PATH; run this from a login shell" >&2
        exit 2
      fi

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      echo "resolving inputs (this fetches)"
      if ! nix flake update --flake "$repo" --output-lock-file "$tmp/flake.lock"; then
        echo "omarchy-update: could not resolve the flake's inputs; nothing was changed" >&2
        exit 2
      fi

      changes=$(moves "$repo/flake.lock" "$tmp/flake.lock")
      if [ -z "$changes" ]; then
        echo "every input already points at its newest revision; nothing to rebuild"
        exit 0
      fi

      echo "inputs that move:"
      printf '%s\n' "$changes"

      install -m644 "$tmp/flake.lock" "$repo/flake.lock"
      echo "flake.lock updated"

      echo "switching to $flake_ref"
      if ! root nixos-rebuild switch --flake "$flake_ref"; then
        echo >&2
        echo "omarchy-update: the switch failed. The running system is unchanged, and" >&2
        echo "flake.lock still names the new inputs." >&2
        echo "  inputs back to what built the running system:" >&2
        echo "    git -C $repo restore flake.lock" >&2
        echo "    sudo nixos-rebuild switch --flake $flake_ref" >&2
        echo "  if the switch did activate and the system came up wrong, back one generation:" >&2
        echo "    sudo nixos-rebuild switch --rollback" >&2
        echo "    sudo nixos-rebuild list-generations" >&2
        exit 1
      fi

      echo "switched. flake.lock is uncommitted:"
      echo "  git -C $repo commit -m 'flake.lock: update inputs' -- flake.lock"
      echo "back one generation if this one misbehaves: sudo nixos-rebuild switch --rollback"
    '';
  };

  available = pkgs.writeShellApplication {
    name = "omarchy-update-available";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.jq
      pkgs.nix
    ];
    text = ''
      export LC_ALL=C

      repo=${lib.escapeShellArg repo}

      usage() {
        cat <<TXT
      omarchy-update-available: report whether the flake's inputs have newer
      revisions.

      Exit codes:
        0  at least one input has a newer revision
        1  every input is at its newest revision
        2  could not tell (not a git work tree, or the inputs did not resolve)

      Nothing is written: the update is resolved into a temporary lock file and
      compared against $repo/flake.lock.
      TXT
      }

      ${lockdiff}

      if [ "$#" -gt 0 ]; then
        case "$1" in
          -h | --help)
            usage
            exit 0
            ;;
          *)
            echo "omarchy-update-available: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
        esac
      fi

      if ! git -C "$repo" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "omarchy-update-available: $repo is not a git work tree" >&2
        exit 2
      fi

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      if ! nix flake update --flake "$repo" --output-lock-file "$tmp/flake.lock" 2> "$tmp/nix.log"; then
        echo "omarchy-update-available: could not resolve the flake's inputs" >&2
        cat "$tmp/nix.log" >&2
        exit 2
      fi

      changes=$(moves "$repo/flake.lock" "$tmp/flake.lock")
      if [ -z "$changes" ]; then
        pinned=$(pins "$repo/flake.lock" | wc -l)
        if [ "$pinned" -eq 1 ]; then
          echo "up to date: 1 pinned input"
        else
          echo "up to date: $pinned pinned inputs"
        fi
        exit 1
      fi

      echo "updates available:"
      printf '%s\n' "$changes"
      exit 0
    '';
  };
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = [ update available ];
  };
}

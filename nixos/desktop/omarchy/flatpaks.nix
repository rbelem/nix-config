# Declarative flatpaks for the desktop user.
#
# Flatpaks installed by hand drift from the configuration, because nothing in
# NixOS records them: services.flatpak installs the flatpak binary and its
# portals, and every app after that is manual. This file makes a declared list
# the source of truth, reconciled by a oneshot that runs `flatpak install --user
# --noninteractive` for each id in programs.omarchy.flatpaks.apps.
#
# The reconciler only adds. An app installed by hand, or removed from the
# declaration, stays installed, so the first rebuild after adding an id changes
# nothing else. Pruning is programs.omarchy.flatpaks.removeUnused, off by
# default, and even then it prunes unused runtimes rather than apps.
#
# The unit is a user unit. A user manager starts at login, so an unreachable
# remote delays neither boot nor the login prompt, and `--user` installs into
# the home of the user whose manager ran it. Nothing orders against
# network-online.target: offline logins exit quietly and converge at the next
# one. To reconcile without logging out, run
# `systemctl --user start flatpak-reconcile` after the rebuild.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.omarchy;

  flatpaks = cfg.flatpaks;

  # Each branch is emitted only when it has work, so the default store path
  # holds one echo and no flatpak call at all, and no variant carries a
  # variable shellcheck would call unused.
  hasWork = flatpaks.apps != [ ] || flatpaks.removeUnused;

  install = lib.optionalString (flatpaks.apps != [ ]) ''
    remote=${lib.escapeShellArg flatpaks.remote}
    remote_url=${lib.escapeShellArg flatpaks.remoteUrl}
    declared=( ${lib.concatMapStringsSep " " lib.escapeShellArg flatpaks.apps} )

    remotes=$("$flatpak" remotes --user --columns=name)

    # A remote the user configured by hand keeps its own URL. The test is
    # local, so a login without network does not fail here, and the add only
    # runs on a machine that has none.
    if ! grep -qxF -- "$remote" <<< "$remotes"; then
      "$flatpak" remote-add --user "$remote" "$remote_url" \
        || echo "flatpak: could not add the $remote remote" >&2
    fi

    failed=0
    for ref in "''${declared[@]}"; do
      # Idempotent by construction: flatpak reports an installed ref as
      # "Skipping: ... already installed" and exits zero.
      "$flatpak" install --user --noninteractive "$remote" "$ref" || {
        echo "flatpak: $ref did not install" >&2
        failed=1
      }
    done

    # An unreachable remote is a normal laptop state, so it is not a failure
    # and the next login retries. A declared id that the reachable remote does
    # not know is a mistake worth surfacing.
    if [ "$failed" -ne 0 ]; then
      if "$flatpak" remote-ls --user --app "$remote" --columns=application >/dev/null 2>&1; then
        echo "flatpak: some declared apps are not installable, see above" >&2
        exit 1
      fi
      echo "flatpak: $remote is unreachable, retrying at next login" >&2
    fi
  '';

  prune = lib.optionalString flatpaks.removeUnused ''
    # Runtimes only. No application is uninstalled even when this is on.
    "$flatpak" uninstall --user --noninteractive --assumeyes --unused
  '';

  reconcile = pkgs.writeShellApplication {
    name = "flatpak-reconcile";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep ];
    text =
      if hasWork then
        lib.concatStrings [
          "flatpak=${config.services.flatpak.package}/bin/flatpak\n"
          install
          prune
        ]
      else ''
        echo "flatpak: nothing declared, leaving the installed apps alone"
      '';
  };
in
{
  options.programs.omarchy.flatpaks = {
    apps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''
        [
          "com.brave.Browser"
          "org.mozilla.firefox"
        ]
      '';
      description = ''
        Flatpak application ids to install for the desktop user, from
        `remote`. Empty by default, so a machine whose flatpaks were installed
        by hand keeps exactly what it has.

        Find an id with `flatpak search <name>`, or read the ids of what is
        already installed with `flatpak list --app --columns=application`. Ids
        are reverse DNS and case sensitive, for example `com.brave.Browser` or
        `org.mozilla.thunderbird`. A ref may pin the branch, as in
        `app/org.gnome.Builder/x86_64/stable`.

        An id removed from this list stays installed. Nothing is uninstalled
        unless `removeUnused` says so, and that only prunes runtimes.
      '';
    };

    remote = lib.mkOption {
      type = lib.types.str;
      default = "flathub";
      description = ''
        Flatpak remote the declared apps come from.
      '';
    };

    remoteUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      description = ''
        Repository file used to add `remote` on a machine that does not have
        it yet. A remote that already exists keeps its own URL.
      '';
    };

    removeUnused = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run `flatpak uninstall --unused` after reconciling. Destructive, and
        off by default.

        It deletes installed runtimes and extensions that no application
        references any more, which is disk space back and local data loss. A
        runtime deleted here has to be downloaded again the next time an app
        that needs it runs, so turning this on makes flatpak depend on the
        network being up. Applications are never uninstalled, whether declared
        here or installed by hand.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && config.services.flatpak.enable) {
    systemd.user.services.flatpak-reconcile = {
      description = "Reconcile the declared flatpaks";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${reconcile}/bin/flatpak-reconcile";
        # Installing several apps over a slow link outlasts the 90 second
        # default, and the timeout only ends this unit, not the session.
        TimeoutStartSec = "15min";
      };
    };
  };
}

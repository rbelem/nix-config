# Attic binary-cache integration for book3 (workstation).
#
# Uploads every successful local build to the private Attic cache
# (attic.zet.rclb.dev, cache `devbox`) via the nix post-build-hook.
#
# Uploads MUST go through the attic client: Attic does not implement the
# standard `nix copy --to` PUT endpoint (HTTP 405 on nar PUT — uploads only
# via the attic client's chunked API; upstream zhaofengli/attic#7).
#
# Auth: the nix daemon runs the hook as root, which reads the push JWT from
# rodrigo's attic CLI config (~/.config/attic/config.toml — maintained by
# `devbox-global/bin/cache configure` or `attic login`). Server-side GC
# retention is 90 days (zet repo, secrets-render.yml server.toml).
{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = [pkgs.attic-client];

  nix.settings.post-build-hook = pkgs.writeShellScript "attic-post-build-hook" ''
    set -eu
    export ATTIC_SERVER="https://attic.zet.rclb.dev"

    ATTIC_CONFIG="/home/rodrigo/.config/attic/config.toml"
    TOKEN="$(sed -n 's/^[[:space:]]*token[[:space:]]*=[[:space:]]*"\(.*\)".*$/\1/p' "$ATTIC_CONFIG" 2>/dev/null || true)"
    if [ -z "''${TOKEN:-}" ]; then
      echo "attic-post-build-hook: no token in $ATTIC_CONFIG — skipping upload" >&2
      exit 0
    fi
    export ATTIC_TOKEN="$TOKEN"

    set -f # disable globbing
    export IFS=' '
    # Best-effort: a cache outage must never fail local builds.
    if ! ${pkgs.attic-client}/bin/attic push devbox $OUT_PATHS >&2; then
      echo "attic-post-build-hook: upload failed (cache unreachable?) — continuing" >&2
    fi
  '';
}

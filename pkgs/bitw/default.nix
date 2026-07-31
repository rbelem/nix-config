# bitw — rbelem Bitwarden CLI fork (D-Bus Secret Service provider)
#
# Bitwarden CLI replacement. Drop-in for `bw` with:
#   - Per-item-key decryption (new Rust CLI 2026.6.0+ wire format)
#   - `bitw get --json <name>` (fully decrypted cipher JSON)
#   - `bitw edit <name>` (notes, password, fields)
#   - `bitw create --type 1|2|5` (login, secure-note, ssh-key)
#   - libsecret auto-unlock + client_credentials auth (BW_CLIENTID/BW_CLIENTSECRET)
#
# Used by the assistant repo's fetch_vault.sh / populate-vault.sh /
# restore-state.sh / rotate-secrets.sh on the operator workstation.
# Intentionally NOT installed on the VPS (agent host) — the master password
# never touches the VPS; vault decryption happens on the workstation and
# rendered secrets are pushed via ansible.

{ pkgs ? (import ../../nixpkgs.nix) { }, ... }:

pkgs.buildGoModule {
  pname = "bitw";

  # mvdan/bitw never published a tagged version. Use 0.1.0 as the implicit
  # baseline for nix package metadata. Wire-protocol clientVersion is a
  # separate constant in api.go (currently "2026.7.0", matching upstream
  # bitwarden/clients CLI per round-2 oracle review).
  version = "0.1.0";

  src = pkgs.fetchFromGitHub {
    owner = "rbelem";
    repo = "bitw";

    # Bump together with the upstream commit SHA on rbelem/bitw master.
    # 4740f8a (item-key decrypt + get --json + edit + create --type 2/5:
    #          adds Cipher.Key field, threads item-key decryption through
    #          findCipherByName/get/dump/cache, adds SshKey struct + CipherSshKey=5,
    #          adds --json emission mode, adds `bitw edit` command, extends
    #          create with --type/--ssh-private-key-stdin/--ssh-public-key.
    #          Fixes per-item-key invisibility for items created by the new
    #          Bitwarden Rust CLI. 265 tests pass. Pushed 2026-07-31).
    rev = "4740f8a15d4f9f9e0fe7a1ecac9294b2ad151cca";
    hash = "sha256-aN1zFNzsWnQpl5FuowERnCWBzNcD94KzMPxUKFt8OS4=";
  };

  # Go modules unchanged across the item-key+edit commit range — vendorHash
  # matches what the devbox-global flake pins.
  vendorHash = "sha256-gD+6wtLtW2Hn9ir6Nrc5eDoGdPoeB3ZIWyInxBoqJJA=";

  # buildGoModule's default checkPhase runs `go vet ./...` and `go test ./...`.
  # The tests require network access (connect to identity.bitwarden.com),
  # which is unavailable in the Nix sandbox. Override to only run vet.
  checkPhase = ''
    runHook preCheck
    go vet ./...
    runHook postCheck
  '';

  meta = {
    description = "Bitwarden CLI replacement (rbelem fork, item-key + edit + get --json)";
    longDescription = ''
      bitw is a drop-in replacement for the deprecated `bw` (npm @bitwarden/cli)
      and supports the new per-item-key wire format used by the Bitwarden Rust
      CLI 2026.6.0+. Auto-unlocks via libsecret (secret-tool lookup
      bitwarden master-password) or PASSWORD env. Supports client_credentials
      auth via BW_CLIENTID/BW_CLIENTSECRET.
    '';
    license = pkgs.lib.licenses.bsd3;
    platforms = pkgs.lib.platforms.unix;
  };
}

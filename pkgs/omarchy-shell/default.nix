# Upstream Omarchy's QuickShell desktop shell, packaged whole.
#
# $out/share/omarchy is the upstream tree minus its authoring-only dirs
# (.github, docs, manual, test, plans). $out/bin holds plain symlinks into
# it, never wrapped copies: the omarchy CLI greps its siblings for
# `# omarchy:summary=`, so a wrapper that moved the scripts would blind it.
# Runtime dependencies ride in environment.systemPackages (see
# nixos/desktop/omarchy/shell.nix), resolved through PATH at runtime.
#
# The install/update/AUR stack ships in the tree but has no pacman on NixOS,
# so it stays vendored-but-unreachable. Only what the shell needs to start
# and serve bar/menu/OSD/lock is patched, each with --replace-fail so an
# upstream move fails the build instead of silently shipping stale text.

{ lib, stdenvNoCC, omarchy-src }:

stdenvNoCC.mkDerivation {
  pname = "omarchy-shell";
  version = lib.trim (builtins.readFile "${omarchy-src}/version");

  src = omarchy-src;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/omarchy
    cp -r $src/. $out/share/omarchy/
    chmod -R u+w $out/share/omarchy
    rm -rf \
      $out/share/omarchy/.git \
      $out/share/omarchy/.github \
      $out/share/omarchy/docs \
      $out/share/omarchy/manual \
      $out/share/omarchy/test \
      $out/share/omarchy/plans

    # The input-method watcher spawns its reader by absolute path.
    substituteInPlace $out/share/omarchy/shell/Commons/InputMethodState.qml \
      --replace-fail '/usr/bin/python3' 'python3'

    # No uwsm session here, so launch desktop entries with gtk-launch itself.
    substituteInPlace $out/share/omarchy/shell/services/AppLibrary.qml \
      --replace-fail 'uwsm-app -- gtk-launch' 'gtk-launch'

    mkdir -p $out/bin
    for script in $out/share/omarchy/bin/*; do
      ln -s "$script" "$out/bin/$(basename "$script")"
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Omarchy desktop shell (QuickShell bar, dock, menu, OSD, lock screen)";
    homepage = "https://omarchy.org";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "omarchy";
  };
}

# fresque — Omarchy wallpaper rotation plugin, packaged for NixOS.
#
# Upstream is Shika34/fresque; this builds rbelem/fresque, which carries the
# NixOS fixes (an /usr/bin/env bash shebang, Omarchy's theme prefix read from
# the omarchy on PATH instead of /usr/share/omarchy), three input fixes, and
# two extra sources (Wallhaven, a local pictures folder). See the fork's log.
#
# Why a wrapper: the plugin's shell runs bin/fresque directly, by absolute path
# taken from its own directory, so PATH is whatever the desktop session has.
# jq, file and ImageMagick are not part of a NixOS system by default, and a
# plugin that dies silently because `jq` is not on the session PATH is worse
# than no plugin. The wrapper pins them where the script will find them and
# leaves the rest of PATH alone, so hyprctl and omarchy still resolve from the
# session as intended.
#
# The output is a plugin directory (manifest.json at its root), which is what
# programs.nixarchy.plugins.<name>.src expects.

{
  lib,
  stdenv,
  fetchgit,
  makeWrapper,
  bash,
  coreutils,
  curl,
  file,
  findutils,
  gawk,
  gnugrep,
  gnused,
  imagemagick,
  jq,
  util-linux,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fresque";
  version = "2.6.0";

  src = fetchgit {
    url = "https://github.com/rbelem/fresque.git";
    # Bump together with the fork's main. rev and version move together:
    # the manifest on that rev carries the version above.
    rev = "842a85b96f0454eb57440f229c53e0716540e41e";
    hash = "sha256-Ro0IMF+7YWaA4E3r3cRrqt9Pr7J25BY5BuUpQhOREG8=";
  };

  nativeBuildInputs = [ makeWrapper ];
  # patchShebangs needs the interpreter the shebang names.
  buildInputs = [ bash ];

  runtimeTools = [
    bash
    coreutils
    curl
    file
    findutils
    gawk
    gnugrep
    gnused
    imagemagick
    jq
    util-linux
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out/
    chmod -R u+w $out
    # docs/ ships screenshots the plugin never loads; they only cost closure
    # size.
    rm -rf $out/docs $out/scripts $out/.gitignore
    patchShebangs $out/bin

    mv $out/bin/fresque $out/bin/fresque-unwrapped
    makeWrapper $out/bin/fresque-unwrapped $out/bin/fresque \
      --prefix PATH : ${lib.makeBinPath finalAttrs.runtimeTools}

    runHook postInstall
  '';

  # The plugin is data plus one script; there is nothing to compile. What can
  # be checked cheaply is that the manifest the shell will read is the one this
  # version claims.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -f $out/manifest.json
    test -x $out/bin/fresque
    test "$($out/bin/fresque help | head -1)" = "fresque: quality wallpapers for Omarchy"
    runHook postInstallCheck
  '';

  meta = {
    description = "Quality wallpapers for Omarchy, rotating on its own (NixOS fork)";
    homepage = "https://github.com/rbelem/fresque";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "fresque";
  };
})

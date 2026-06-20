{ stdenv, lib, merlin-src }:

# Static web UI files from Merlin — no compilation needed.
# These are the HTML, JS, CSS, and image files served by httpd.

stdenv.mkDerivation {
  pname = "merlin-www";
  version = "merlin-ng";

  src = merlin-src;

  buildPhase = "true";

  installPhase = ''
    mkdir -p $out/www
    cp -r $src/release/src-rt-5.02axhnd/router/www/* $out/www/
    chmod -R u+w $out/www
  '';

  meta = {
    description = "ASUSWRT-Merlin web UI static files";
    platforms = lib.platforms.all;
    license = lib.licenses.gpl2Only;
  };
}

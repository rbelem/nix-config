{ pkgs, lib, ... }: {
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      caladea
      carlito
      corefonts
      dejavu_fonts
      open-sans
      overpass
      roboto
      roboto-mono
      roboto-slab
      gyre-fonts
      ubuntu_font_family
      courier-prime
      gelasio
      merriweather
      source-sans-pro
    ];
  };
}

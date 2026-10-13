{ pkgs, lib, ... }: {
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      cantarell-fonts # GNOME UI font — fixes OnlyOffice Flatpak dialog/button tofu (missing in sandbox)
      caladea
      carlito
      corefonts
      dejavu_fonts
      # Replaces the hand-linked ~/.local/share/fonts farm whose nix store
      # target was garbage-collected (fontconfig served dead paths -> dialog tofu)
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      unifont
      open-sans
      overpass
      roboto
      roboto-mono
      roboto-slab
      gyre-fonts
      ubuntu-classic
      courier-prime
      gelasio
      merriweather
      source-sans-pro
    ];
    fontconfig = {
      defaultFonts = {
        serif = [ "DejaVu Serif" ];
        sansSerif = [ "DejaVu Sans" ];
        monospace = [ "Roboto Mono" ];
      };
      hinting.enable = true;
      hinting.style = "slight";
      subpixel.rgba = "rgb";
      subpixel.lcdfilter = "light";
    };
  };
}

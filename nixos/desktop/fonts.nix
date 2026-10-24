{ pkgs, lib, ... }: {
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      cantarell-fonts # GNOME UI font — fixes OnlyOffice Flatpak dialog/button tofu (missing in sandbox)
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
      ubuntu-classic
      courier-prime
      gelasio
      merriweather
      source-sans-pro
      nerd-fonts.jetbrains-mono # Omarchy's terminal font, and the monospace default
    ];
    fontconfig = {
      defaultFonts = {
        serif = [ "DejaVu Serif" ];
        sansSerif = [ "DejaVu Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
      hinting.enable = true;
      hinting.style = "slight";
      subpixel.rgba = "rgb";
      subpixel.lcdfilter = "light";
    };
  };
}

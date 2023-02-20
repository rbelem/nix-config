{ pkgs, config, ... }: {
  home.packages = with pkgs; [
    python310Packages.pip
    python3Full
  ];
}

{ pkgs, config, ... }:
let
  # cli to update the sha256
  # nix-prefetch fetchFromGitHub --owner nvchad --repo nvchad --rev 32b0a008a96a3dd04675659e45a676b639236a98
  nvchadConfig = pkgs.fetchFromGitHub {
      owner = "nvchad";
      repo = "nvchad";
      rev = "8214d4e8589aa6625c6db077b8eb199e7ebc1929";
      sha256 = "sha256-1w7RPJ5EXD73pkeJV0mt3daaMHPiRQgtHT/OUErfDi4=";
  };
in {
  home.packages = with pkgs; [
    # Installation dependencies
    cargo
    gcc
    go
    rustc
    unzip

    # Runtime dependencies
    deno
    nixfmt
    nixpkgs-fmt
    nodejs
    # python deps installed by
    # ../python
    perl536Packages.PerlTidy
    ripgrep
    statix
    tfsec
    tree-sitter
    wl-clipboard
    xclip
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  xdg.configFile."nvim/init.lua" = {
    source = nvchadConfig + "/init.lua";
    recursive = true;
  };

  xdg.configFile."nvim/lua/core" = {
    source = nvchadConfig + "/lua/core";
    recursive = true;
  };

  xdg.configFile."nvim/lua/plugins" = {
    source = nvchadConfig + "/lua/plugins";
    recursive = true;
  };

  xdg.configFile."nvim/lua/custom" = {
    source = ./lua/custom;
    recursive = true;
  };
}

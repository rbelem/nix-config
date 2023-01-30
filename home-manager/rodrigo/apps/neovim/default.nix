{ pkgs, config, ... }:
let
  # cli to update the sha256
  # nix-prefetch fetchFromGitHub --owner nvchad --repo nvchad --rev b9ec202f79148f60be142f88b11a01d7292b4e74
  nvchadConfig = pkgs.fetchFromGitHub {
      owner = "nvchad";
      repo = "nvchad";
      rev = "d3ddae598f788140bd965c0f1e4450b9bde8a2a0";
      sha256 = "sha256-p6NbShmA039vP1BIGmOxwjleuSu3SI8/9qn49Wi+scM=";
  };
in {
  home.packages = with pkgs; [
    # Installation dependencies
    cargo
    gcc
    rustc
    unzip

    # Runtime dependencies
    nodejs
    python310Packages.pip
    python3Full
    ripgrep
    tree-sitter
    xclip
  ];

  xdg.configFile.nvim = {
    source = nvchadConfig;
    recursive = true;
  };

  xdg.configFile."nvim/lua/custom/mappings.lua" = {
    source = ./lua/custom/mappings.lua;
    recursive = true;
  };

  xdg.configFile."nvim/lua/custom/chadrc.lua" = {
    source = ./lua/custom/chadrc.lua;
    recursive = true;
  };

  xdg.configFile."nvim/lua/custom/plugins/init.lua" = {
    source = ./lua/custom/plugins/init.lua;
    recursive = true;
  };

  xdg.configFile."nvim/lua/custom/plugins/lspconfig.lua" = {
    source = ./lua/custom/plugins/lspconfig.lua;
    recursive = true;
  };
}

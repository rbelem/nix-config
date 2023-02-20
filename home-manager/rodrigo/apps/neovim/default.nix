{ pkgs, config, ... }:
let
  # cli to update the sha256
  # nix-prefetch fetchFromGitHub --owner nvchad --repo nvchad --rev 32b0a008a96a3dd04675659e45a676b639236a98
  nvchadConfig = pkgs.fetchFromGitHub {
      owner = "nvchad";
      repo = "nvchad";
      rev = "32b0a008a96a3dd04675659e45a676b639236a98";
      sha256 = "sha256-IfVcysO6LTm7xFv5m7+GExmplj0P+IVGSeoMCT9qvBY=";
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

  xdg.configFile."nvim/lua/custom/plugins/null-ls.lua" = {
    source = ./lua/custom/plugins/null-ls.lua;
    recursive = true;
  };
}

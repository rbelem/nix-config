{ pkgs, config, ... }:
let
  # cli to update the sha256
  # nix-prefetch fetchFromGitHub --owner nvchad --repo nvchad --rev b9ec202f79148f60be142f88b11a01d7292b4e74
  nvchadConfig = pkgs.fetchFromGitHub {
      owner = "nvchad";
      repo = "nvchad";
      rev = "b9ec202f79148f60be142f88b11a01d7292b4e74";
      sha256 = "sha256-8k2gWEIUWV998j6Jsvb2ubEm8zw8nj+lAX7JXJM2bPQ=";
  };
in {
  home.packages = with pkgs; [
    ripgrep
  ];

  xdg.configFile.nvim = {
    source = nvchadConfig;
    recursive = true;
  };
}

{ pkgs, lib, ... }: {

  environment.systemPackages = with pkgs; [
    neovim
  ];

  programs.neovim.enable = true;

  environment.variables.EDITOR = "nvim";
}

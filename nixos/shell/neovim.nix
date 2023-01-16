{ pkgs, lib, ... }: {

  environment.systemPackages = with pkgs; [
    neovim
  ];

  programs.neovim.enable = true;
  programs.neovim.viAlias = true;
  programs.neovim.vimAlias = true;

  environment.variables.EDITOR = "nvim";
}

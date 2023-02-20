{ pkgs, config, ... }: {
  home.packages = with pkgs; [
    python310Packages.ipdb
    python310Packages.ipython
    python310Packages.ipython_genutils
    python310Packages.pip
    python3Full
  ];

  home.file.".ipython/profile_default/ipython_config.py" = {
    recursive = true;
    text = ''
      c.TerminalInteractiveShell.editor = "vi"
      c.TerminalInteractiveShell.editing_mode = "vi"
      c.TerminalInteractiveShell.emacs_bindings_in_vi_insert_mode = False
    '';
  };

}

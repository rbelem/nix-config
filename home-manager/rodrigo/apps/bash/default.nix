{ config, pkgs, ... }:
{
  programs.bash = {
    enable = true;

    # Eternal bash history, found here: https://stackoverflow.com/questions/9457233/unlimited-bash-history
    # ---------------------
    # Undocumented feature which sets the size to "unlimited".
    # http://stackoverflow.com/questions/9457233/unlimited-bash-history
    historySize = -1;
    historyFileSize = -1;

    # Change the file location because certain bash sessions truncate .bash_history file upon close.
    # http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
    historyFile = "${config.home.homeDirectory}/.bash_history_";

    historyControl = [
      "erasedups"
      "ignoredups"
      "ignorespace"
    ];

    historyIgnore = [
      "bg"
      "cd"
      "clear"
      "env"
      "exit"
      "fg"
      "history"
      "htop"
      "ls"
      "ps *"
      "top"
    ];

    shellOptions = [
      # Append to history file rather than replacing it.
      "histappend"

      # check the window size after each command and, if
      # necessary, update the values of LINES and COLUMNS.
      "checkwinsize"

      # Extended globbing.
      "extglob"
      "globstar"

      # Warn if closing shell with running jobs.
      "checkjobs"

      # Store multi-line commands in one history entry
      "cmdhist"
    ];

    sessionVariables = {
      GCM_CREDENTIAL_STORE = "secretservice";
      HISTTIMEFORMAT = "%F %T ";

      # Force prompt to write history after every command.
      # http://superuser.com/questions/20900/bash-history-loss
      PROMPT_COMMAND="history -a; $PROMPT_COMMAND";
    };

    shellAliases = {
      g = "${pkgs.git}/bin/git";
      lg = "lazygit";

      # Project tmux.
      pux = "sh -c \"tmux -S $(pwd).tmux attach\"";

      jqless = "jq -C | less -r";

      n = "nix";
      nd = "nix develop -c $SHELL";
      ns = "nix shell";
      nsn = "nix shell nixpkgs#";
      nb = "nix build";
      nbn = "nix build nixpkgs#";
      nf = "nix flake";

      nr = "nixos-rebuild --flake .";
      nrs = "nixos-rebuild --flake . switch";
      snr = "sudo nixos-rebuild --flake .";
      snrs = "sudo nixos-rebuild --flake . switch";
      hm = "home-manager --flake .";
      hms = "home-manager --flake . switch";

      e = "nvim";
      ee = "nvim \"$(fzf)\"";

      tmp = "cd $(mktemp -d)";

      cd = "z";
    };

    initExtra = ''
      # make less more friendly for non-text input files, see lesspipe(1)
      [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

      # No locking on Ctrl-S
      stty -ixon

      set -o vi
    '';
  };
}

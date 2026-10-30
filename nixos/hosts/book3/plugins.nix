# Omarchy shell plugins this machine installs declaratively.
#
# Why here and not `omarchy plugin add`: that writes an untracked directory into
# ~/.config/omarchy/plugins, which no rebuild reproduces and no second machine
# gets. programs.nixarchy.plugins symlinks the plugin out of the store under the
# id in its own manifest, and validates that manifest at build time.
#
# Installing is not enabling. The shell records enablement in shell.json once,
# and keeps it, so a plugin removed from here stays on until it is turned off in
# Setup > Plugins.
#
# fresque is rbelem/fresque: upstream Shika34/fresque with the NixOS fixes and
# three input fixes, plus Wallhaven and a local pictures folder as sources. Its
# settings live in ~/.config/omarchy/fresque.json and are changed with
# `fresque config set <key> <value>`.
{ pkgs, ... }:
{
  # The plugins option is home-manager's (nixarchy's home layer), so it is set
  # through the user rather than at the system level, unlike programs.nixarchy.apps.
  home-manager.users.rodrigo.programs.nixarchy.plugins.fresque.src = pkgs.fresque;
}

{ config, ... }: {
  imports = [
    ./alien.nix
    ./locales.nix
    ./nix.conf.nix
    ./timezone.nix
  ];

  environment.variables = {
    EDITOR = "vi";
    VISUAL = "vi";
  };
}

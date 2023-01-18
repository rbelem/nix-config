{ config, ... }: {
  imports = [
    ./locales.nix
    ./nix.conf.nix
    ./timezone.nix
  ];
}

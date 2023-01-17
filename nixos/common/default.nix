{ config, ... }: {
  imports = [
    ./locales.nix
    ./nix.conf.nix
    ./sops.nix
    ./timezone.nix
  ];
}

{
  description = "rbelem's NixOS config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    hardware.url = "github:nixos/nixos-hardware";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
      inherit (self) outputs;
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Reusable nixos modules
      # These are usually stuff to upstream into nixpkgs
      nixosModules = import ./modules/nixos;

      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs outputs; };

      # Custom packages
      # Acessible through 'nix build', 'nix shell', etc
      packages = forAllSystems (system:
        import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; }
      );

      # Devshell for bootstrapping
      # Acessible through 'nix develop' or 'nix-shell' (legacy)
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = rec {
        # Laptop
        book3 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [ ./nixos/hosts/book3 ];
        };
      };
    };
}

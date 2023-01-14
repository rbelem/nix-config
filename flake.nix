{
  description = "rbelem's NixOS config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";

    # Home manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      inherit (self) outputs;
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    rec {
      # Reusable nixos modules
      # These are usually stuff to upstream into nixpkgs
      nixosModules = import ./modules/nixos;

      # Reusable home-manager modules
      # These are usually stuff to upstream into home-manager
      homeManagerModules = import ./modules/home-manager;

      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays;

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
        odyssey = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [ ./nixos/hosts/odyssey ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        # Laptop
        "rodrigo@odyssey" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [ ./home-manager/rodrigo/hosts/odyssey.nix ];
        };
      };
    };
}

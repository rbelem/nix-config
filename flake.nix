{
  description = "rbelem's NixOS config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    hardware.url = "github:nixos/nixos-hardware";

    # ASUS GPL source for RT-AX88U (firmware 3.0.0.4.388_24209)
    # Extracted to local filesystem, tracked as a flake path input
    asus-gpl-rtax88u.url = "path:/home/rodrigo/Workspace/rbelem/RT-AX88U/asuswrt";
    asus-gpl-rtax88u.flake = false;

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
      inherit (self) outputs;
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Reusable nixos modules
      nixosModules = import ./modules/nixos;

      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs outputs; };

      # Custom packages
      # Accessible through 'nix build', 'nix shell', etc
      # RT-AX88U packages are cross-compiled to aarch64 from any system
      packages = forAllSystems (system:
        import ./pkgs {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit inputs;
        }
      );

      # Devshell for bootstrapping
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      # Validation checks (nix flake check)
      checks = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
            custom = import ./pkgs { inherit pkgs inputs; };
        in {
          rt-ax88u-validation = custom.rt-ax88u-validation or null;
        }
      );

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = rec {
        # Laptop
        book3 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs outputs; };
          modules = [ ./nixos/hosts/book3 ];
        };

        # Router — cross-built from x86_64, runs on aarch64-linux
        rt-ax88u = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/hosts/rt-ax88u
            # Apply overlay so pkgs.rt-ax88u-bsp-kernel and pkgs.merlin-web-ui
            # are available in NixOS modules when cross-evaluated
            { nixpkgs.overlays = [ outputs.overlays.additions ]; }
          ];
        };
      };
    };
}

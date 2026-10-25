{
  description = "rbelem's NixOS config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    hardware.url = "github:nixos/nixos-hardware";

    # Pinned nixpkgs for systemd v258 (kernel 4.1 compat)
    # systemd v260+ requires kernel >= 5.10, BSP kernel is 4.1.51
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-25.11";

    # ASUS GPL source for RT-AX88U (firmware 3.0.0.4.388_24209)
    # Extracted to local filesystem, tracked as a flake path input
    #asus-gpl-rtax88u.url = "path:/home/rodrigo/Workspace/rbelem/RT-AX88U/asuswrt";
    #asus-gpl-rtax88u.flake = false;

    # zet repo — provides .rendered/runtime-config.json (domain, backup S3, etc.)
    # Regenerate with: scripts/fetch_vault.sh (in the zet repo)
    zet-repo = {
      url = "path:/home/rodrigo/Workspace/github.com/rbelem/zet";
      flake = false;
    };

    # OpenLogi — local-first Logitech HID++ peripheral manager (Rust/GPUI).
    # Provides packages.openlogi + nixosModules.default (programs.openlogi).
    openlogi = {
      url = "github:AprilNEA/OpenLogi";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Omarchy — the upstream desktop tree (bar, dock, menu, OSD, lock screen
    # as a QuickShell application plus its bin/ commands). Fetched whole and
    # packaged under pkgs/omarchy-shell; not a flake (no outputs to use).
    omarchy = {
      url = "github:omacom/omarchy";
      flake = false;
    };

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

            # A minimal configuration that exercises the Omarchy module, so
            # the desktop check can validate what the module generates
            # without building a whole system.
            omarchySmoke = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = { inherit inputs outputs; };
              modules = [
                { nixpkgs.overlays = [ outputs.overlays.additions ]; }
                ./nixos/desktop/omarchy
                ({ ... }: {
                  system.stateVersion = "25.11";
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "none";
                    fsType = "ext4";
                  };
                  programs.omarchy.enable = true;
                })
              ];
            };
        in {
          rt-ax88u-validation = custom.rt-ax88u-validation or null;

          # The Omarchy desktop: Hyprland's scrolling layout is the niri-style
          # one, and xdg-desktop-portal-hyprland ships the GlobalShortcuts
          # backend, so the compositor needs no patches. The check asserts the
          # generated configuration parses with Hyprland's own verifier, that
          # it is the scrolling layout with translated keybindings, that the
          # session is offered to the greeter, that the portal routes
          # GlobalShortcuts to Hyprland, and that the terminals read the theme.
          omarchy-desktop = if system == "x86_64-linux" then
            pkgs.runCommand "omarchy-desktop-check" { } ''
              set -eu

              export HOME=$TMPDIR
              export XDG_RUNTIME_DIR=$TMPDIR/runtime
              mkdir -p "$XDG_RUNTIME_DIR"

              hyprland=${omarchySmoke.config.programs.hyprland.package}/bin/Hyprland
              portal=${omarchySmoke.config.programs.hyprland.portalPackage}
              conf=${omarchySmoke.config.environment.etc."omarchy/hyprland.lua".source}

              echo "the portal ships the GlobalShortcuts backend"
              grep -q "org.freedesktop.impl.portal.GlobalShortcuts" \
                $portal/share/xdg-desktop-portal/portals/hyprland.portal

              echo "the generated configuration parses"
              $hyprland --verify-config --config $conf

              echo "the shell package ships its entry point"
              test -f ${custom.omarchy-shell}/share/omarchy/shell/shell.qml

              echo "the session autostarts the shell"
              grep -qF 'hl.exec_cmd("omarchy-launch-shell")' $conf

              echo "the layout is niri's scrolling one"
              grep -qF 'layout = "scrolling"' $conf

              echo "the keybindings are Hyprland dispatcher calls"
              grep -qF 'hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = "1", follow = true })' $conf
              grep -F 'hl.bind("XF86AudioRaiseVolume"' $conf | grep -qF 'locked = true'

              echo "the session is offered to the greeter"
              found=0
              for pkg in ${nixpkgs.lib.concatStringsSep " " (map toString omarchySmoke.config.services.displayManager.sessionPackages)}; do
                if [ -e "$pkg/share/wayland-sessions/omarchy.desktop" ]; then
                  found=1
                fi
              done
              [ "$found" -eq 1 ] || { echo "no omarchy wayland session"; exit 1; }

              echo "the portal routes GlobalShortcuts to Hyprland"
              grep -q "org.freedesktop.impl.portal.GlobalShortcuts=hyprland" \
                ${omarchySmoke.config.environment.etc."xdg/xdg-desktop-portal/hyprland-portals.conf".source}

              echo "the niri fork is gone"
              ! grep -q "niri-global-shortcuts" \
                ${./pkgs/default.nix} \
                ${./nixos/desktop/omarchy/default.nix} \
                ${./nixos/desktop/omarchy/hyprland-config.nix} \
                ${./nixos/desktop/omarchy/bindings.nix} \
                ${./nixos/desktop/omarchy/session.nix}

              echo "the terminals read the theme"
              mkdir -p theme config
              cp ${omarchySmoke.config.environment.etc."omarchy/theme/foot".source} theme/foot
              cp ${omarchySmoke.config.environment.etc."omarchy/theme/alacritty".source} theme/alacritty
              cp ${omarchySmoke.config.environment.etc."omarchy/theme/kitty".source} theme/kitty
              cp ${omarchySmoke.config.environment.etc."omarchy/theme/ghostty".source} theme/ghostty
              cp ${omarchySmoke.config.environment.etc."omarchy/config/foot".source} config/foot
              cp ${omarchySmoke.config.environment.etc."omarchy/config/alacritty".source} config/alacritty
              cp ${omarchySmoke.config.environment.etc."omarchy/config/kitty".source} config/kitty
              cp ${omarchySmoke.config.environment.etc."omarchy/config/ghostty".source} config/ghostty
              sh ${./nixos/desktop/omarchy/check-terminal-themes.sh} \
                "$PWD" \
                ${pkgs.foot}/bin/foot \
                ${pkgs.alacritty}/bin/alacritty \
                ${pkgs.kitty}/bin/kitty \
                ${pkgs.ghostty}/bin/ghostty

              touch $out
            ''
          else null;
        }
      );

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = rec {
        # Laptop
        book3 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/hosts/book3
            # The additions overlay carries the custom packages.
            { nixpkgs.overlays = [ outputs.overlays.additions ]; }
          ];
        };

        # Router — cross-built from x86_64, runs on aarch64-linux
        rt-ax88u = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/hosts/rt-ax88u
            # overlays: additions first (rt-ax88u-bsp-kernel, merlin-web-ui, etc.),
            # then systemd-old (v258 from nixos-25.11 — kernel 4.1 compat)
            { nixpkgs.overlays = [
              outputs.overlays.additions
              outputs.overlays.systemd-old
            ]; }
          ];
        };

        # VPS zet — Hetzner Cloud NixOS host running k3s + Caddy + Tailscale
        zet = let
          runtime-config = import ./lib/runtime-config.nix {
            zet-repo = inputs.zet-repo;
          };
        in nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs outputs runtime-config; };
          modules = [
            ./nixos/hosts/zet
          ];
        };
      };
    };
}

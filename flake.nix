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

          # The shell tree the desktop's features come from: the entry point,
          # the plugin directories behind the bar, dock, menu, OSD, lock screen
          # and background, and the bin/ verbs the session autostart and the
          # generated keybindings call by bare name. Upstream moving one of
          # those is a blank screen at login with no error on it; here it is a
          # failed check.
          omarchy-shell-tree = if system == "x86_64-linux" then
            pkgs.runCommand "omarchy-shell-tree-check" { } ''
              set -eu
              shell=${custom.omarchy-shell}

              echo "the shell package ships its entry point"
              test -f $shell/share/omarchy/shell/shell.qml

              echo "the plugin directories the desktop is made of are there"
              for plugin in bar dock menu osd lock background; do
                if [ ! -d "$shell/share/omarchy/shell/plugins/$plugin" ]; then
                  echo "  missing plugin directory: $plugin"
                  exit 1
                fi
              done

              echo "the verbs the session and the keybindings call are executable"
              for verb in omarchy omarchy-launch-shell omarchy-menu omarchy-menu-keybindings; do
                if [ ! -x "$shell/bin/$verb" ]; then
                  echo "  missing verb: $verb"
                  exit 1
                fi
              done

              touch $out
            ''
          else null;

          # The generated configuration as the session reads it: the autostart
          # line that starts the shell, and a binding table that still emits.
          # 74 binds are in it today; the floor is 60, so ordinary keybinding
          # edits do not trip it and a table that stops emitting does.
          omarchy-generated-config = if system == "x86_64-linux" then
            pkgs.runCommand "omarchy-generated-config-check" { } ''
              set -eu
              conf=${omarchySmoke.config.environment.etc."omarchy/hyprland.lua".source}

              echo "the session autostarts the shell"
              grep -qF 'hl.exec_cmd("omarchy-launch-shell")' $conf

              echo "the keybinding table still emits"
              binds=$(grep -c 'hl.bind(' $conf || true)
              echo "  $binds binds"
              [ "$binds" -ge 60 ] || { echo "  the binding table stopped emitting"; exit 1; }

              touch $out
            ''
          else null;

          # Every theme the option can name, against the two readers that only
          # see it once it is selected: wallpaper.nix names the first background
          # in sort order, and the login oneshot copies the theme out of the
          # shell package. A directory the shell package does not ship cannot be
          # switched to, and breaks the login when it is the default. colors.toml
          # itself is parsed for every theme at eval (theme.nix renders all the
          # palettes), so this asks only that the file is there.
          omarchy-themes = if system == "x86_64-linux" then
            pkgs.runCommand "omarchy-themes-check" { } ''
              set -eu
              export LC_ALL=C

              themes=${./nixos/desktop/omarchy/themes}
              shipped=${custom.omarchy-shell}/share/omarchy/themes

              for dir in "$themes"/*; do
                theme=$(basename "$dir")
                echo "theme $theme"

                if [ ! -f "$dir/colors.toml" ]; then
                  echo "  no colors.toml"
                  exit 1
                fi

                background=
                for candidate in "$dir"/backgrounds/*; do
                  if [ -f "$candidate" ]; then
                    background=$(basename "$candidate")
                    break
                  fi
                done
                if [ -z "$background" ]; then
                  echo "  no background to stage"
                  exit 1
                fi
                echo "  background $background"

                if [ ! -f "$shipped/$theme/colors.toml" ]; then
                  echo "  the shell package does not ship this theme"
                  exit 1
                fi
              done

              touch $out
            ''
          else null;

          # The install menu's declaration file: Nix that the next rebuild
          # imports, written by omarchy-apps-toggle and copied into the tree by
          # omarchy-apps-apply. A file that does not parse breaks the rebuild's
          # eval, after the command that wrote it has already exited, so the
          # toggle is run here in both directions against a scratch HOME.
          # --store dummy:// because a build sandbox has no store to open.
          omarchy-install-menu = if system == "x86_64-linux" then
            pkgs.runCommand "omarchy-install-menu-check" {
              nativeBuildInputs = [ pkgs.nix ] ++ builtins.filter
                (p: builtins.elem (p.name or "") [ "omarchy-apps-search" "omarchy-apps-toggle" ])
                omarchySmoke.config.environment.systemPackages;
            } ''
              set -eu
              export HOME=$TMPDIR/home
              mkdir -p "$HOME"

              declaration=$HOME/.config/omarchy/apps.nix

              # Any catalogue app will do, so take the first one: the check then
              # says nothing about which apps the catalogue holds.
              app=$(omarchy-apps-search "" | sed -n '1s/^ *\([^ ]*\).*/\1/p')
              if [ -z "$app" ]; then
                echo "the app catalogue is empty"
                exit 1
              fi

              echo "the toggle writes a declaration that parses"
              omarchy-apps-toggle "$app" > /dev/null
              nix-instantiate --parse --store dummy:// "$declaration" > /dev/null
              grep -qxF "  programs.omarchy.apps.$app.enable = true;" "$declaration"

              echo "and it still parses with that app switched back off"
              omarchy-apps-toggle "$app" > /dev/null
              nix-instantiate --parse --store dummy:// "$declaration" > /dev/null
              if grep -qxF "  programs.omarchy.apps.$app.enable = true;" "$declaration"; then
                echo "  the second toggle left it on"
                exit 1
              fi

              # apps.local.nix is untracked until omarchy-apps-apply adds it, so
              # the flake only sees it once that command has run.
              repository=${if builtins.pathExists ./nixos/desktop/omarchy/apps.local.nix
                           then "${./nixos/desktop/omarchy/apps.local.nix}"
                           else ""}
              if [ -n "$repository" ]; then
                echo "the declaration this checkout carries parses"
                nix-instantiate --parse --store dummy:// "$repository" > /dev/null
              else
                echo "no apps.local.nix in this checkout; nothing to import yet"
              fi

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

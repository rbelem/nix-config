{ pkgs, inputs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./k3s.nix
    ./caddy.nix
    ./firewall.nix
    ./tailscale.nix
    ./backup.nix
    ./state-snapshot.nix

    ../../common
    ../../users/rodrigo
  ];

  # Nix
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # User
  users.users.rodrigo = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # ssh-ed25519 from Bitwarden assistant/vps-ssh-key (private key stored there)
      # Verified: matches ssh-keygen -y of bw private key. github.com/rbelem.keys empty
      # (no cross-verification possible). Used as sole VPS SSH auth.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINg0Z6Pj23jHaM4B2cXPJ2ETD2EP4/L3ZL9qwmn0Qvw0"
    ];
  };

  # Allow running unpatched binaries
  programs.nix-ld.enable = true;

  # Locale
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Targeted sudo NOPASSWD for rodrigo — single-operator VPS, defense-in-depth
  # via command allowlist. Anything not listed still prompts for the password.
  # Commands needing automation: nixos-rebuild, systemctl, tailscale, k3s.
  security.sudo.extraRules = [
    {
      users = [ "rodrigo" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/tailscale";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/k3s";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # State version
  system.stateVersion = "24.11";
}

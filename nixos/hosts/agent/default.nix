{ pkgs, inputs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./k3s.nix
    ./caddy.nix
    ./firewall.nix
    ./tailscale.nix
    ./backup.nix
    ./secrets.nix

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
    shell = pkgs.bash;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # Fetch from GitHub
      # Run: curl -sL https://github.com/rbelem.keys
      # Paste the keys here for offline builds
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

  # Timezone
  time.timeZone = "REDACTED-TZ";

  # State version
  system.stateVersion = "24.11";
}

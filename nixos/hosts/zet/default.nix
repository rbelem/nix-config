{ pkgs, inputs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./k3s.nix
    ./caddy.nix
    ./firewall.nix
    ./tailscale.nix
    ./backup.nix

    ../../common
    ../../users/rodrigo
  ];

  # Nix
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      # rodrigo must be able to nix-copy-closure for `nixos-rebuild --target-host`
      # from the workstation (deploy.sh). Without this, the remote daemon
      # (require-sigs = true) rejects unsigned closure copies as a non-trusted user.
      trusted-users = [ "root" "rodrigo" ];
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
      # ssh-ed25519 from Bitwarden zet/vps-ssh-key (private key stored there).
      # Rotated 2026-07-31 together with a VM reprovision — old key (Ng0Z6Pj2) was
      # authorized on the previous VPS but its private half only survived in a stale
      # .rendered/ file; the vault item had been rotated without updating this list.
      # Verify with: ssh-keygen -y -f <(bitw get --json zet/vps-ssh-key | jq -r .sshKey.privateKey)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAa+66tokO+iGCEAIFzy0juOh20T+jaz8gaM76qE/eW zet-vps-2026-07-31"
    ];
  };

  # Allow running unpatched binaries
  programs.nix-ld.enable = true;

  # Note: bitw is intentionally NOT installed on the VPS. Vault decryption
  # happens on the operator workstation (see AGENTS.md in the zet repo);
  # the VPS only receives rendered k8s Secrets / config files via ansible.
  # The master password never touches the VPS. If you need bitw on a host
  # other than zet, import pkgs/bitw in that host's configuration.

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

  # /var/log must not be group-writable: logrotate refuses btmp/wtmp rotation
  # ("parent directory has insecure permissions") when /var/log is 775 root:syslog.
  # 'd' only sets mode at creation; 'z' fixes the existing dir (nixos-infect left
  # an Ubuntu-userland 775 root:syslog /var/log behind).
  systemd.tmpfiles.rules = [
    "d /var/log 0755 root root -"
    "z /var/log 0755 root root -"
  ];

  # nixos-infect leftover: Ubuntu's /usr/lib/tmpfiles.d/00rsyslog.conf sets
  # `z /var/log 0775 root syslog`, which overrides our /etc rule (tmpfiles.d
  # precedence: /usr/lib beats /etc) and breaks logrotate-checkconf. Remove it.
  system.activationScripts.removeUbuntuRsyslogTmpfiles = ''
    rm -f /usr/lib/tmpfiles.d/00rsyslog.conf
  '';
}

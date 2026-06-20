{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.merlin-webui;

in {
  options.services.merlin-webui = {
    enable = mkEnableOption "ASUSWRT-Merlin web UI";

    package = mkOption {
      type = types.package;
      description = "Merlin httpd package with web UI";
    };

    www = mkOption {
      type = types.path;
      description = "Path to the www/ directory with web UI files";
    };

    listenPort = mkOption {
      type = types.port;
      default = 80;
      description = "HTTP listen port";
    };

    securePort = mkOption {
      type = types.port;
      default = 443;
      description = "HTTPS listen port";
    };

    nvramConfig = mkOption {
      type = types.path;
      default = "";
      description = "Path to pre-populated NVRAM config file";
    };

    loglevel = mkOption {
      type = types.enum [ "0" "1" "2" "3" "4" "5" "6" "7" ];
      default = "3";
      description = "syslog level for httpd";
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug mode with verbose logging";
    };
  };

  config = mkIf cfg.enable {
    # Required kernel features (must be enabled in BSP kernel)
    boot.kernelParams = [ ];

    # Create system user for httpd
    users.users.merlin-webui = {
      description = "Merlin web UI daemon";
      isSystemUser = true;
      group = "merlin-webui";
    };
    users.groups.merlin-webui = {};

    # Runtime directory for httpd
    systemd.tmpfiles.rules = [
      "d /var/run/merlin-webui 0755 merlin-webui merlin-webui -"
      "d /var/www 0755 merlin-webui merlin-webui -"
      "d /var/log/merlin 0755 merlin-webui merlin-webui -"
    ];

    # Link www files
    system.activationScripts.merlin-webui = ''
      if [ -d "${cfg.www}" ]; then
        ln -sfn ${cfg.www} /var/www
      fi
    '';

    # systemd service for httpd
    systemd.services.merlin-webui = {
      description = "ASUSWRT-Merlin Web UI";
      after = [ "network.target" "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];

      # If httpd binary is not available, start a stub that
      # redirects to a maintenance page
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";

        # Main httpd command — runs in foreground
        # httpd -p <port> -w <wwwdir> -n <nvramfile>
        ExecStart = ''
          ${cfg.package}/sbin/httpd \
            -p ${toString cfg.listenPort} \
            -w /var/www \
            ${optionalString (cfg.nvramConfig != "") "-n ${cfg.nvramConfig}"} \
            -l ${cfg.loglevel} \
            ${optionalString cfg.debug "-d"}
        '';

        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          "/var/run/merlin-webui"
          "/var/log/merlin"
          "/var/www"
        ];

        # Capabilities needed for network access
        AmbientCapabilities = "CAP_NET_BIND_SERVICE CAP_NET_RAW";
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE CAP_NET_RAW";
      };
    };

    # Alternative: lighttpd as a fallback if Merlin httpd is unavailable
    services.lighttpd = mkIf (!pathExists "${cfg.package}/sbin/httpd") {
      enable = true;
      documentRoot = "/var/www";
      port = cfg.listenPort;
      enableModules = [ "mod_cgi" "mod_redirect" ];
    };

    # Firewall — open web UI ports
    networking.firewall.allowedTCPPorts = [
      cfg.listenPort
    ] ++ optional (cfg.listenPort != cfg.securePort && cfg.securePort != 0)
      cfg.securePort;

    # Log rotation
    services.logrotate.settings.merlin-webui = {
      files = "/var/log/merlin/*.log";
      rotate = 7;
      size = "10M";
      compress = true;
    };
  };
}

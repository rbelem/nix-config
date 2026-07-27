{ pkgs, ... }: {
  # Tailscale VPN
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "/etc/tailscale/authkey";
    extraUpFlags = [
      "--hostname=agent"
      "--accept-routes"
    ];
  };

  # Make tailscale CLI available
  environment.systemPackages = [ pkgs.tailscale ];

  # Tag the node after connect (oneshot)
  systemd.services.tailscale-tag = {
    description = "Tag Tailscale node";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "tailscale-tag" ''
        #!${pkgs.bash}/bin/bash
        # Wait for tailscale to be connected
        for i in $(seq 1 30); do
          if ${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -e '.Self.Online' 2>/dev/null; then
            ${pkgs.tailscale}/bin/tailscale set --advertise-tags=tag:agent
            exit 0
          fi
          sleep 2
        done
        echo "Tailscale did not come online in 60s"
        exit 1
      '';
    };
  };
}

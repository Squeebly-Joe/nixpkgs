{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.hawser;
  settingsFormat = pkgs.formats.keyValue {};
in
{
  meta.maintainers = with lib.maintainers; [
    Squeebly-Joe
  ];

  options.services.hawser = {
    enable = lib.mkEnableOption "Hawser Remote Docker Agent";

    package = lib.mkPackageOption pkgs "hawser" { };

    openFirewall = (lib.mkEnableOption "") // {
      description = "Whether to open the firewall port.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2376;
      description = "Change the defaut port used for Standard mode.";
    };

    token = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Authentication token (Insecure: use environmentFile instead).";
    };
    
    dockhandServer.url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "WebSocket URL for Edge mode (wss://dockehand.example.com/api/hawser/connect).";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        File path containing secrets for configuring the hawser service in the format of an EnvironmentFile. See {manpage}`systemd.exec(5).
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = {};
      description = ''
        Configuration for Hawser, written to {file}`/etc/hawser/config` as
        KEY=VALUE pairs and loaded by the service as an EnvironmentFile.

        See <https://github.com/Finsys/hawser?tab=readme-ov-file#configuration>
        for the full list of available options.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.hawser = {
      isSystemUser = true;
      group = "hawser";
    };

    users.groups.hawser = { };

    environment.etc."hawser/config" = {
      source = settingsFormat.generate "config" (
        {
          PORT = toString cfg.port;
        }
        // lib.optionalAttrs (cfg.dockhandServer.url != null) {
          DOCKHAND_SERVER_URL = cfg.dockhandServer.url;
        }
        // lib.optionalAttrs (cfg.dockhandServer.url != null && cfg.token == null) {
          TOKEN = "placeholder";
        }
        // lib.optionalAttrs (cfg.token != null) {
          TOKEN = cfg.token;
        }
        // cfg.settings
      );
      mode = "0640";
      user = "hawser";
      group = "hawser";
    };

    systemd.services.hawser = {
      description = "Hawser - Remote Docker Agent for Dockhand";
      documentation = [ "https://github.com/Finsys/hawser" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # For container runtime access
      path =
        pkgs.lib.optionals config.virtualisation.docker.enable [pkgs.docker]
        ++ pkgs.lib.optionals config.virtualisation.podman.enable [pkgs.podman];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/hawser";

        EnvironmentFile = [
          "/etc/hawser/config"
        ] ++ lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        
        SupplementaryGroups =
          lib.optionals config.virtualisation.docker.enable [ "docker" ]
          ++ lib.optionals (
            config.virtualisation.podman.enable && config.virtualisation.podman.dockerSocket.enable
          ) [ "podman" ];

        DynamicUser = true;
        User = "hawser";
        Group = "hawser";

        # Stacks directory must be writable
        ReadWritePaths = [ "/var/run/docker.sock" "/data/stacks" ];

        # Security hardening
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectControlGroups = "strict";
        ProtectHome = "read-only";
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        Restart = "on-failure";
        RestartSec = "10s";
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = [ "@system-service" ];
        Type = "simple";
        UMask = 27;
      };
    };

    # Ensure agent directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d /data 2775 hawser hawser -"
      "d /data/stacks 2775 hawser hawser -"
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      (cfg.port)
    ];
  };
}
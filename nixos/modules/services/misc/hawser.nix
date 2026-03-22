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
      description = "Whether to open the firewall port (default 2376).";
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
      description = "WebSocket URL for Edge mode.";
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

    # Write non-secret settings to /etc/hawser/config (mode 0640, hawser-readable)
    environment.etc."hawser/config" = {
      source = settingsFormat.generate "config" cfg.settings;
      mode = "0640";
      user = "hawser";
      group = "hawser";
    };

    systemd.services.hawser = {
      description = "Hawser - Remote Docker Agent for Dockhand";
      documentation = [ "https://github.com/Finsys/hawser" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "docker.service"
      ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/hawser";
        Restart = "always";
        RestartSec = "10s";

        # Load generated config first, then secrets (secrets win on collision)
        EnvironmentFile = [
          "/etc/hawser/config"
        ] ++ lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        SupplementaryGroups =
          lib.optionals config.virtualisation.docker.enable [ "docker" ]
          ++ lib.optionals (
            config.virtualisation.podman.enable && config.virtualisation.podman.dockerSocket.enable
          ) [ "podman" ];

        User = "hawser";
        Group = "hawser";

        # Stacks directory must be writable
        ReadWritePaths = [ cfg.settings.STACKS_DIR "/var/run/docker.sock" ];

        # Security hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectControlGroups = "strict";
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallFilter = [ "@system-service" ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      (cfg.port)
    ];
  };
}
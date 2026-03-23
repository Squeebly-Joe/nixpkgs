{ 
  pkgs,
  lib,
  ... 
}:
{
  name = "hawser";

  meta.maintainers = with lib.maintainers; [
    Squeebly-Joe
  ];

  nodes = {
    # Standard mode
    standard = { config, pkgs, ... }: {

      # Docker is required by the service
      virtualisation.docker.enable = true;

      services.hawser = {
        enable = true;
        openFirewall = true;
        port = 2376;
        settings = {
          STACKS_DIR = "/var/lib/hawser/stacks";
        };
      };
    };

    # Edge mode
    edge = { config, pkgs, ... }: {

      virtualisation.docker.enable = true;

      services.hawser = {
        enable = true;
        port = 2376;
        dockhandServer.url = "wss://dockhand.example.com";
        settings = {
          STACKS_DIR = "/var/lib/hawser/stacks";
        };
      };
    };
  };

  testScript = ''
  start_all()

  with subtest("standard: service starts and stays running"):
    standard.wait_for_unit("hawser.service")
    standard.sleep(5)
    standard.succeed("systemctl is-active hawser.service")

  with subtest("standard: hawser healthcheck passes"):
    standard.succeed("${pkgs.hawser}/bin/hawser healthcheck")

  with subtest("edge: service starts and stays running without dockhand"):
    edge.wait_for_unit("docker.service")
    edge.wait_for_unit("hawser.service")
    edge.sleep(5)
    edge.succeed("systemctl is-active hawser.service")
'';
}
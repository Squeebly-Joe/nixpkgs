{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "hawser";
  version = "0.2.42";

  src = fetchFromGitHub {
    owner = "Finsys";
    repo = "hawser";
    rev = "v${version}";
    hash = "sha256-1m6j42fM97qSf+YVJnknQmJV3uVgf4qqJDX8XekqP1Y=";
  };

  vendorHash = "sha256-Edr6beVlkHcHj1Jx4vxnJBeVov5sSPKO8dR1G2fQ7l8=";

  subPackages = [ "./cmd/hawser" ];

  ldflags = [
    "-s" "-w"
    "-X main.version=${version}"
  ];

  meta = with lib; {
    description = "Remote Docker Agent for Dockhand";
    homepage = "https://github.com/Finsys/hawser";
    license = licenses.mit;
    maintainers = with lib.maintainers; [ Squeebly-Joe ];
    mainProgram = "hawser";
  };
}
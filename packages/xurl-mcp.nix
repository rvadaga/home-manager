{
  lib,
  buildGoModule,
  fetchFromGitHub,
  gitMinimal,
}:

buildGoModule rec {
  pname = "xurl-mcp";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "xdevplatform";
    repo = "xurl";
    rev = "v${version}";
    hash = "sha256-dwVBzuUhQpfRWFOZOf1DCGNKoetdZlcretnyv9AShbw=";
  };

  nativeBuildInputs = [ gitMinimal ];

  postPatch = ''
    git apply --recount --unidiff-zero ${./xurl-refresh-lock.patch}
  '';

  vendorHash = "sha256-3yUZZYHcDpCaK55uiVw4X9mxvda9iL+XwPpSXheKOSc=";
  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
    "-X github.com/xdevplatform/xurl/version.Version=${version}"
    "-X github.com/xdevplatform/xurl/version.Commit=v${version}"
  ];

  postInstall = ''
    mv "$out/bin/xurl" "$out/bin/xurl-mcp"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    versionOutput="$("$out/bin/xurl-mcp" --version)"
    [[ "$versionOutput" == *"xurl version ${version}"* ]]
    helpOutput="$("$out/bin/xurl-mcp" mcp --help)"
    [[ "$helpOutput" == *"Bridge a stdio MCP client"* ]]
  '';

  meta = {
    description = "x api mcp bridge with cross-process oauth refresh coordination";
    homepage = "https://github.com/xdevplatform/xurl";
    license = lib.licenses.mit;
    mainProgram = "xurl-mcp";
  };
}

{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.1.1";
  sources = {
    aarch64-darwin = {
      asset = "darwin-arm64";
      hash = "sha256-8Jqssu5y/bHUAe5PW5DgYpGahS/Dx7Zr8bGoUxBGF9g=";
    };
    x86_64-darwin = {
      asset = "darwin-amd64";
      hash = "sha256-QHQPgmRcKMTh2kfGvQKmrEl9OCpFfBCTaUozaxdQr3E=";
    };
    aarch64-linux = {
      asset = "linux-arm64";
      hash = "sha256-LaE/jEbydwI3x0SzQatr6fB1CFhaZ2JjTEqIqjVUYLw=";
    };
    x86_64-linux = {
      asset = "linux-amd64";
      hash = "sha256-ntEDk0+rD5DTNB/fxKNCeFOW059WIfxzE6YmAs4rVGI=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "gh-stack does not publish an asset for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "gh-stack";
  inherit version;

  src = fetchurl {
    url = "https://github.com/github/gh-stack/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m 0755 "$src" "$out/bin/gh-stack"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/gh-stack" --version | grep -F "gh stack version ${version}"
    "$out/bin/gh-stack" push --help | grep -F "gh stack push"
    "$out/bin/gh-stack" view --help | grep -F "gh stack view"
    "$out/bin/gh-stack" rebase --help | grep -F "gh stack rebase"
    "$out/bin/gh-stack" rebase --help | grep -F -- "--continue"
    runHook postInstallCheck
  '';

  meta = {
    description = "official github cli extension for stacked pull requests";
    homepage = "https://github.com/github/gh-stack";
    license = lib.licenses.mit;
    mainProgram = "gh-stack";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}

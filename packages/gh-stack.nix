{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.3.0";
  sources = {
    aarch64-darwin = {
      asset = "darwin-arm64";
      hash = "sha256-cMDLETRq1dT5egKlz1JCBSJU0XddNW3AdZ8DVFeHOFA=";
    };
    x86_64-darwin = {
      asset = "darwin-amd64";
      hash = "sha256-7eodXz7ID+ZZb0TUOGBLBYRvy8rD//Bwfb5wcXlL1qk=";
    };
    aarch64-linux = {
      asset = "linux-arm64";
      hash = "sha256-gD7JHuupsqw4gn4pmnmDD+dcpyhPDCjWDmonBLs07RM=";
    };
    x86_64-linux = {
      asset = "linux-amd64";
      hash = "sha256-lX6CLPp+Q1zYSil82WxBm1jlHjrFi+JJdiwkvZ5FCZs=";
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

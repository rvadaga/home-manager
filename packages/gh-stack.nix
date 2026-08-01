{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.1.0";
  sources = {
    aarch64-darwin = {
      asset = "darwin-arm64";
      hash = "sha256-XKmCQaJl1t4BgJXNrl88QNpcp4JFDuwOqRqo4+sYMQM=";
    };
    x86_64-darwin = {
      asset = "darwin-amd64";
      hash = "sha256-cSJmk5v0A0nc5siJMDe4jgRTM00w0GdQthzhpshkC7k=";
    };
    aarch64-linux = {
      asset = "linux-arm64";
      hash = "sha256-p5ZJ4SGEW3QEEJ3iHWVgHAnIxtAh2Tc4o0KNI5hqiEE=";
    };
    x86_64-linux = {
      asset = "linux-amd64";
      hash = "sha256-NYVS3X3OCkbOFT/hlicM7EgrhPCAlHiQqtQGGo1EvAs=";
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

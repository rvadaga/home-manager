{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "4.11.0";
  sources = {
    aarch64-darwin = {
      asset = "macOS_arm64";
      hash = "sha256:d66049692424b1e91014df792b38000709c5361429e3f17f53e64720d8aeabbc";
    };
    x86_64-darwin = {
      asset = "macOS_amd64";
      hash = "sha256:9a7520bbba68f9943e010e3e1cb7375fab0b4935b4edc5aa4bcd87cd0402e1de";
    };
    aarch64-linux = {
      asset = "linux_arm64";
      hash = "sha256:b8ae47ae5545240cdcd21ec85a40a56dea26e7f07320733a6e5266188c1b66dc";
    };
    x86_64-linux = {
      asset = "linux_amd64";
      hash = "sha256:faebd25d8d27513b95aaabbfda3b73f80c7059c01a53bde65dcf2e9ba6f89afb";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Slack CLI does not publish an asset for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "slack-cli-official";
  inherit version;

  src = fetchurl {
    url = "https://github.com/slackapi/slack-cli/releases/download/v${version}/slack_cli_${version}_${source.asset}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = ".";
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/slack "$out/bin/slack"
    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/slack-home"
    mkdir -p "$HOME"
    "$out/bin/slack" version --skip-update | grep -F "${version}"
    "$out/bin/slack" --help --skip-update | grep -F "auth"
    runHook postInstallCheck
  '';

  meta = {
    description = "Official Slack CLI for building Slack apps";
    homepage = "https://github.com/slackapi/slack-cli";
    license = lib.licenses.asl20;
    mainProgram = "slack";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}

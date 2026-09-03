{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.151.0";
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-aarch64-apple-darwin.tar.gz";
    hash = "sha256-y25466gMG8MQpTP28cbJSDd3M7wG+eg3lJM04Eq96cY=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    tar -xzf "$src" -C "$out"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/bin/codex"
    test -x "$out/bin/codex-code-mode-host"
    "$out/bin/codex" --version | grep -F "codex-cli ${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "openai codex cli and its code mode host";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}

{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

let
  version = "0.1.0-2181";
in
stdenvNoCC.mkDerivation {
  pname = "rex";
  inherit version;

  src = fetchurl {
    url = "https://blob.superlogical.com/public/rex-app/preview/Rex-${version}.dmg";
    hash = "sha256-T8jTPn+5cV8XtYMXzIrueqAu3+Uavn4Scv7DyMR2rb0=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  # Fixups would modify the vendor-signed app bundle.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -a Rex.app "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Terminal workspace for coding agents";
    homepage = "https://www.superlogical.com/rex";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}

{ config, lib, pkgs, ... }:
let
  extension = pkgs.unstable.vscode-extensions.leanprover.lean4;
  code = if pkgs.stdenv.hostPlatform.isDarwin then
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  else "${config.home.profileDirectory}/bin/code";
in {
  home.activation.installLeanEditorExtension = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x ${lib.escapeShellArg code} ]; then
      run ${pkgs.python3}/bin/python3 ${../scripts/ensure-lean-extension.py} \
        --code ${lib.escapeShellArg code} \
        --vsix ${extension.src} --version ${extension.version}
    fi
  '';
}

{ config, lib, pkgs, ... }:
let
  styles = ../dotfiles/editor-preview;
  version = (builtins.fromJSON (builtins.readFile (styles + "/package.json"))).version;
  code = "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code";
  vsix = pkgs.runCommand "markdown-preview-style-${version}.vsix" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    python3 ${../scripts/package-preview-style.py} ${styles} "$out"
  '';
in {
  home.file = {
    ".config/editor-preview/preview.css".source = styles + "/preview.css";
    ".config/editor-preview/jetbrains-dark.css".text =
      builtins.readFile (styles + "/preview.css") + builtins.readFile (styles + "/dark.css");
    ".config/editor-preview/jetbrains-light.css".text =
      builtins.readFile (styles + "/preview.css") + builtins.readFile (styles + "/light.css");
    ".config/editor-preview/fixture.md".source = styles + "/fixture.md";
    ".config/editor-preview/README.md".source = styles + "/README.md";
  };

  home.activation.installMarkdownPreviewStyle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x ${lib.escapeShellArg code} ]; then
      run ${pkgs.python3}/bin/python3 ${../scripts/install-preview-style.py} \
        --code ${lib.escapeShellArg code} --vsix ${vsix} \
        --extensions ${lib.escapeShellArg "${config.home.homeDirectory}/.vscode/extensions"}
    fi
  '';
}

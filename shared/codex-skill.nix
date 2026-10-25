{ pkgs }:
let
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
in
name: source:
pkgs.runCommand "codex-skill-${name}" { } ''
  mkdir -p "$out"
  cp -R ${source}/. "$out/"
  chmod -R u+w "$out"
  ${python}/bin/python ${../scripts/normalize-codex-skill-names.py} skill "$out" \
    --expected-name ${pkgs.lib.escapeShellArg name}
''

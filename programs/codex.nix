{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  # merge nested tables recursively and union arrays across nix-owned pieces.
  deepMerge = import ../shared/deep-merge.nix { inherit lib; };

  tomlFormat = pkgs.formats.toml { };
  nixMergedSettings = tomlFormat.generate "codex-settings-nix-merged.toml" (
    lib.recursiveUpdate (lib.foldl deepMerge { } config.codex.settingsPieces) config.codex.forcedSettings
  );
  forcedSettings = tomlFormat.generate "codex-settings-forced.toml" config.codex.forcedSettings;
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.tomli-w ]);

  mergeCodexSettings = pkgs.writeShellScript "merge-codex-settings" ''
    exec ${python}/bin/python ${../scripts/merge-codex-settings.py} "$@"
  '';
in
{
  options.codex.settingsPieces = mkOption {
    type = types.listOf types.attrs;
    default = [ ];
    description = "list of config.toml pieces to merge additively into the live file on each activation";
  };

  options.codex.forcedSettings = mkOption {
    type = types.attrs;
    default = { };
    description = "config.toml values that replace live values on each activation; other live settings are preserved";
  };

  config = mkIf (config.codex.settingsPieces != [ ] || config.codex.forcedSettings != { }) {
    home.activation.mergeCodexSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${mergeCodexSettings} "$HOME/.codex/config.toml" "${nixMergedSettings}" "${forcedSettings}"
    '';
  };
}

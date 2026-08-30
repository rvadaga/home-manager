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
    lib.foldl deepMerge { } config.codex.settingsPieces
  );
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.tomli-w ]);

  mergeCodexSettingsPython = pkgs.writeText "merge-codex-settings.py" ''
    import os
    import pathlib
    import sys
    import tempfile
    import tomllib

    import tomli_w


    def load_toml(path):
        try:
            with path.open("rb") as file:
                return tomllib.load(file)
        except tomllib.TOMLDecodeError as error:
            raise SystemExit(f"cannot merge codex settings: invalid toml in {path}: {error}")


    def deep_merge(nix_value, live_value):
        if isinstance(nix_value, dict) and isinstance(live_value, dict):
            merged = dict(nix_value)
            for key, value in live_value.items():
                if key in merged:
                    merged[key] = deep_merge(merged[key], value)
                else:
                    merged[key] = value
            return merged

        if isinstance(nix_value, list) and isinstance(live_value, list):
            merged = list(live_value)
            for item in nix_value:
                if item not in merged:
                    merged.append(item)
            return merged

        return live_value


    target = pathlib.Path(sys.argv[1])
    nix_merged = pathlib.Path(sys.argv[2])
    target.parent.mkdir(parents=True, exist_ok=True)

    if not target.exists():
        if target.is_symlink():
            target.unlink()
        target.write_bytes(nix_merged.read_bytes())
        target.chmod(0o600)
        print(f"seeded {target} from nix config")
        raise SystemExit(0)

    if not target.is_file():
        raise SystemExit(f"cannot merge codex settings: {target} is not a regular file")

    nix_settings = load_toml(nix_merged)
    live_settings = load_toml(target)

    merged_settings = deep_merge(nix_settings, live_settings)
    file_descriptor, temporary_name = tempfile.mkstemp(
        dir=target.parent,
        prefix=".codex-settings-merge.",
    )
    temporary_path = pathlib.Path(temporary_name)
    try:
        with os.fdopen(file_descriptor, "wb") as file:
            tomli_w.dump(merged_settings, file)
        temporary_path.chmod(0o600)
        temporary_path.replace(target)
    finally:
        temporary_path.unlink(missing_ok=True)

    print(f"merged nix settings into {target}")
  '';

  mergeCodexSettings = pkgs.writeShellScript "merge-codex-settings" ''
    exec ${python}/bin/python ${mergeCodexSettingsPython} "$@"
  '';
in
{
  options.codex.settingsPieces = mkOption {
    type = types.listOf types.attrs;
    default = [ ];
    description = "list of config.toml pieces to merge additively into the live file on each activation";
  };

  config = mkIf (config.codex.settingsPieces != [ ]) {
    home.activation.mergeCodexSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${mergeCodexSettings} "$HOME/.codex/config.toml" "${nixMergedSettings}"
    '';
  };
}

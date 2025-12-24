{ config, lib, ... }:

with lib;

{
  options.claude = {
    settingsPieces = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "list of settings.json pieces to merge";
    };

    settingsLocalPieces = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "list of settings.local.json pieces to merge";
    };
  };

  config = {
    home.file = {
      ".claude/settings.json".text = builtins.toJSON (
        lib.foldl lib.recursiveUpdate {} config.claude.settingsPieces
      );
      ".claude/settings.local.json".text = builtins.toJSON (
        lib.foldl lib.recursiveUpdate {} config.claude.settingsLocalPieces
      );
    };
  };
}

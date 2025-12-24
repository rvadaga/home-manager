{ config, lib, ... }:

with lib;

{
  options.claude = {
    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "claude code settings.json content";
    };

    settingsLocal = mkOption {
      type = types.attrs;
      default = {};
      description = "claude code settings.local.json content";
    };
  };

  config = {
    home.file = {
      ".claude/settings.json".text = builtins.toJSON config.claude.settings;
      ".claude/settings.local.json".text = builtins.toJSON config.claude.settingsLocal;
    };
  };
}

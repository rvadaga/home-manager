{ config, lib, pkgs, ... }:

with lib;

let
  mergedLocalSettings = builtins.toJSON (
    lib.foldl lib.recursiveUpdate {} config.claude.settingsLocalPieces
  );
in
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
      description = "list of settings.local.json pieces to merge (seeded once, then owned by claude code)";
    };
  };

  config = {
    home.file = {
      ".claude/settings.json".text = builtins.toJSON (
        lib.foldl lib.recursiveUpdate {} config.claude.settingsPieces
      );
    };

    home.activation.seedClaudeLocalSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      local_settings="$HOME/.claude/settings.local.json"
      if [ ! -f "$local_settings" ] || [ -L "$local_settings" ]; then
        # remove symlink if home-manager previously managed this file
        [ -L "$local_settings" ] && rm "$local_settings"
        echo '${mergedLocalSettings}' > "$local_settings"
        echo "seeded $local_settings from nix config"
      fi
    '';
  };
}

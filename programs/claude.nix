{ config, lib, pkgs, ... }:

with lib;

let
  mergedSettings = builtins.toJSON (
    lib.foldl lib.recursiveUpdate {} config.claude.settingsPieces
  );
  mergedLocalSettings = builtins.toJSON (
    lib.foldl lib.recursiveUpdate {} config.claude.settingsLocalPieces
  );
  seedFile = ''
    if [ ! -f "$1" ] || [ -L "$1" ]; then
      [ -L "$1" ] && rm "$1"
      echo '$2' > "$1"
      echo "seeded $1 from nix config"
    fi
  '';
in
{
  options.claude = {
    settingsPieces = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "list of settings.json pieces to merge (seeded once, then owned by claude code)";
    };

    settingsLocalPieces = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "list of settings.local.json pieces to merge (seeded once, then owned by claude code)";
    };
  };

  config = {
    home.activation.seedClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      seed_claude_file() {
        if [ ! -f "$1" ] || [ -L "$1" ]; then
          # remove symlink if home-manager previously managed this file
          [ -L "$1" ] && rm "$1"
          echo "$2" > "$1"
          echo "seeded $1 from nix config"
        fi
      }

      seed_claude_file "$HOME/.claude/settings.json" '${mergedSettings}'
      seed_claude_file "$HOME/.claude/settings.local.json" '${mergedLocalSettings}'
    '';
  };
}

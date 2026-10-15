{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  # arrays concatenate and deduplicate so os-specific settings add to the base.
  deepMerge = import ../shared/deep-merge.nix { inherit lib; };

  nixMergedSettingsJson = builtins.toJSON (
    lib.recursiveUpdate (lib.foldl deepMerge { } config.claude.settingsPieces) config.claude.forcedSettings
  );
  nixMergedSettings = pkgs.writeText "claude-settings-nix-merged.json" nixMergedSettingsJson;
  forcedSettings = pkgs.writeText "claude-settings-forced.json" (builtins.toJSON config.claude.forcedSettings);
  jq = "${pkgs.jq}/bin/jq";
in
{
  options.claude = {
    forcedSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "settings.json values that replace live values on each activation; other live settings are preserved";
    };

    settingsPieces = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "list of settings.json pieces to merge additively into the live file on each activation";
    };
  };

  config = {
    home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      merge_claude_file() {
        local target="$1"
        local nix_merged="$2"

        if [ ! -f "$target" ] || [ -L "$target" ]; then
          # first run or leftover symlink — seed from nix merged settings
          [ -L "$target" ] && rm "$target"
          cp "$nix_merged" "$target"
          echo "seeded $target from nix config"
        else
          # declared forced settings replace live values; other live scalars keep their values.
          local merged
          merged=$(${jq} -s -f ${../scripts/merge-claude-settings.jq} "$nix_merged" "$target" "${forcedSettings}")
          chmod u+w "$target"
          echo "$merged" > "$target"
          echo "merged nix settings into $target"
        fi
      }

      merge_claude_file "$HOME/.claude/settings.json" "${nixMergedSettings}"
    '';
  };
}

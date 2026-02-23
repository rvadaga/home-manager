{ config, lib, pkgs, ... }:

with lib;

let
  # deep merge that concatenates + deduplicates arrays instead of replacing them.
  # lib.recursiveUpdate replaces arrays wholesale, which breaks os-specific permissions.
  deepMerge = a: b:
    let
      mergeable = key:
        builtins.hasAttr key a && builtins.hasAttr key b
        && builtins.isAttrs a.${key} && builtins.isAttrs b.${key};
      concatable = key:
        builtins.hasAttr key a && builtins.hasAttr key b
        && builtins.isList a.${key} && builtins.isList b.${key};
    in
    a // b //
    (lib.filterAttrs (k: _: mergeable k) (
      builtins.mapAttrs (k: _: deepMerge a.${k} b.${k})
        (lib.intersectAttrs a b)
    )) //
    (lib.filterAttrs (k: _: concatable k) (
      builtins.mapAttrs (k: _: lib.unique (a.${k} ++ b.${k}))
        (lib.intersectAttrs a b)
    ));

  mergedSettings = builtins.toJSON (
    lib.foldl deepMerge {} config.claude.settingsPieces
  );
  jq = "${pkgs.jq}/bin/jq";

  # jq filter: deep merge two objects with array union.
  # baseline (.[0]) provides new keys; live file (.[1]) wins on scalar conflicts.
  # uses two-argument def form to avoid jq scoping issues with reduce.
  deepMergeFilter = ''
    def deep_merge(a; b):
      a as $aa | b as $bb |
      if ($aa | type) == "object" and ($bb | type) == "object" then
        (($aa | keys_unsorted) + ($bb | keys_unsorted)) | unique |
        reduce .[] as $k ({};
          if ($aa | has($k)) and ($bb | has($k)) then
            . + {($k): deep_merge($aa[$k]; $bb[$k])}
          elif ($bb | has($k)) then . + {($k): $bb[$k]}
          else . + {($k): $aa[$k]}
          end
        )
      elif ($aa | type) == "array" and ($bb | type) == "array" then
        ($aa + $bb) | unique
      else $bb
      end;
    deep_merge(.[0]; .[1])
  '';
in
{
  options.claude = {
    settingsPieces = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "list of settings.json pieces to merge additively into the live file on each activation";
    };
  };

  config = {
    home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      merge_claude_file() {
        local target="$1"
        local baseline="$2"

        if [ ! -f "$target" ] || [ -L "$target" ]; then
          # first run or leftover symlink — seed from baseline
          [ -L "$target" ] && rm "$target"
          echo "$baseline" > "$target"
          echo "seeded $target from nix config"
        else
          # additive merge: baseline brings new keys/entries, live wins on conflicts
          local merged
          merged=$(${jq} -s '${deepMergeFilter}' <(echo "$baseline") "$target")
          echo "$merged" > "$target"
          echo "merged nix baseline into $target"
        fi
      }

      merge_claude_file "$HOME/.claude/settings.json" '${mergedSettings}'
    '';
  };
}

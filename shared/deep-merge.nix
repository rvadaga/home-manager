{ lib }:
let
  deepMerge =
    left: right:
    let
      mergeable =
        key:
        builtins.hasAttr key left
        && builtins.hasAttr key right
        && builtins.isAttrs left.${key}
        && builtins.isAttrs right.${key};
      concatable =
        key:
        builtins.hasAttr key left
        && builtins.hasAttr key right
        && builtins.isList left.${key}
        && builtins.isList right.${key};
    in
    left
    // right
    // (lib.filterAttrs (key: _: mergeable key) (
      builtins.mapAttrs (key: _: deepMerge left.${key} right.${key}) (lib.intersectAttrs left right)
    ))
    // (lib.filterAttrs (key: _: concatable key) (
      builtins.mapAttrs (key: _: lib.unique (left.${key} ++ right.${key})) (lib.intersectAttrs left right)
    ));
in
deepMerge

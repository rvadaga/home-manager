{ config, pkgs, lib, ... }:

let
  macSettings = builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-mac.json);
  macSettingsLocal = builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-mac.json);
in

{
  # claude configuration
  claude.settings = lib.mkMerge [ config.claude.settings macSettings ];
  claude.settingsLocal = lib.recursiveUpdate config.claude.settingsLocal macSettingsLocal;

  home = {
    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-mac.md
    );

    packages = [
      pkgs.unstable.coreutils-full
      # g-prefixed symlinks for gnu coreutils (avoids collision with coreutils-prefixed)
      (pkgs.runCommand "coreutils-gprefixed" {} ''
        mkdir -p $out/bin
        for cmd in ${pkgs.unstable.coreutils-full}/bin/*; do
          name=$(basename "$cmd")
          ln -s "$cmd" "$out/bin/g$name"
        done
      '')
      pkgs.pinentry_mac
    ];
  };
}

{ config, pkgs, lib, ... }: {
  # claude configuration
  claude.settingsPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-mac.json)) ];
  claude.settingsLocalPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-mac.json)) ];

  home = {
    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-mac.md
    );

    packages = [
      pkgs.unstable.coreutils-prefixed  # g-prefixed gnu coreutils (gpaste, gstat, etc.)
      pkgs.pinentry_mac
    ];
  };
}

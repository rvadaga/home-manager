{ config, pkgs, lib, ... }: {
  # claude configuration
  claude.settingsPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-nixos.json)) ];
  claude.settingsLocalPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-nixos.json)) ];

  home = {
    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-nixos.md
    );

    packages = [
      pkgs.unstable.claude-code
    ];
  };
}

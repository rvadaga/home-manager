{ config, pkgs, lib, ... }: {
  # claude configuration
  claude.settingsPieces = lib.mkAfter [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-nixos.json)) ];
  claude.settingsLocalPieces = lib.mkAfter [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-nixos.json)) ];

  home = {
    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-nixos.md
    );

    packages = [
      pkgs.unstable.claude-code
    ];
  };

  imports = [
    ../programs/vscode.nix
  ];

  programs = {
    zsh = {
      shellAliases = {
        nosc = "cd $HOME/.config/nixos";
      };
    };
  };
}

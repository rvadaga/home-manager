{ config, pkgs, lib, ... }:

let
  nixosSettings = builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-nixos.json);
  nixosSettingsLocal = builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-nixos.json);
in

{
  # claude configuration
  claude.settings = lib.mkMerge [ config.claude.settings nixosSettings ];
  claude.settingsLocal = lib.recursiveUpdate config.claude.settingsLocal nixosSettingsLocal;

  home = {
    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-nixos.md
    );

    packages = [
      pkgs.unstable.claude-code
    ];
  };
}

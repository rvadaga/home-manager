{ config, pkgs, lib, ... }:

let
  linuxSettings = builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-linux.json);
  linuxSettingsLocal = builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-linux.json);
in

{
  # claude configuration
  claude.settings = lib.mkMerge [ config.claude.settings linuxSettings ];
  claude.settingsLocal = lib.recursiveUpdate config.claude.settingsLocal linuxSettingsLocal;

  home = {
    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-linux.md
    );

    packages = [
      pkgs.pinentry-curses
    ];
  };

  programs = {
    zsh = {
      initContent = ''
        source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
      '';
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableZshIntegration = true;
      pinentry.package = pkgs.pinentry-curses;
    };
  };
}

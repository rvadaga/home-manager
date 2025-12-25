{ config, pkgs, lib, ... }: {
  # claude configuration
  claude.settingsPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-linux.json)) ];
  claude.settingsLocalPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-linux.json)) ];

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
        if [ -e $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
          source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
        fi
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

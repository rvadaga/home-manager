{ config, pkgs, lib, ... }: {
  # claude configuration
  claude.settingsPieces = lib.mkAfter [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-linux.json)) ];
  home = {
    file.".codex/AGENTS.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/codex/AGENTS-linux.md
    );

    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-linux.md
    );

    packages = [
      pkgs.pinentry-curses
    ];

    sessionVariables = {
      LANG = "C.UTF-8";
    };
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

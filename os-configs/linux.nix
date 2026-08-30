{ config, pkgs, lib, ... }: {
  llmInstructions.platforms = [ "linux" ];

  home = {
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

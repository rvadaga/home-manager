{ config, pkgs, ... }: {
  programs.zsh = {
    enable = true;

    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      # home-manager
      hmc = "cd $HOME/.config/home-manager";

      # k8s
      k = "kubectl";
      ctx = "kubectx";
      ns = "kubens";
    };

    history = {
      size = 100000000;
      share = true;
    };

    localVariables = {
      POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
      ];
    };

    plugins = [
      {
        name = "powerlevel10k-config";
        src = ../dotfiles;
        file = ".p10k.zsh";
      }
      {
        name = "zsh-powerlevel10k";
        src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
        file = "powerlevel10k.zsh-theme";
      }
    ];

    initContent = ''
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # source some helper functions
      source ~/.config/home-manager/scripts/functions.sh;
    '';
  };
}

{ ... }: {
  programs.zsh = {
    enable = true;

    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      # home-manager
      hmc = "cd $HOME/.config/home-manager";

      # bat
      b = "bat -P";

      # chrome
      chrome = "open -a 'Google Chrome' --args --remote-debugging-port=9222";

      # k8s
      k = "kubectl";
      ctx = "kubectx";
      ns = "kubens";
    };

    history = {
      size = 100000000;
      share = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
      ];
    };

    initContent = ''
      # oh-my-zsh defines __git_prompt_git in lib/git.zsh but claude code's
      # shell snapshot filters __ prefixed functions. redefine it here so
      # aliases like ggpush/ggpull that depend on git_current_branch work
      # in claude code's bash subshell.
      function __git_prompt_git() {
        GIT_OPTIONAL_LOCKS=0 command git "$@"
      }

      # enable menu completion (cycle through options with tab)
      zstyle ':completion:*' menu select

      # use gnu ls (gls) with LS_COLORS for better color support
      zstyle ':omz:lib:theme-and-appearance' gnu-ls yes

      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # source some helper functions
      source ~/.config/home-manager/scripts/functions.sh;
    '';
  };
}

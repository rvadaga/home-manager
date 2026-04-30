{ ... }: {
  programs.zsh = {
    enable = true;

    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      # home-manager
      hmc = "cd $HOME/.config/home-manager";

      # dev repos
      dev = "cd $HOME/development";
      dln = "cd $HOME/development/llm-notes";

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
      # fall back to xterm-256color if the current TERM has no matching terminfo entry
      # (common when SSH'ing from ghostty into a machine without its terminfo installed)
      if ! infocmp "$TERM" &>/dev/null 2>&1; then
        export TERM=xterm-256color
      fi

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

      # override omz git plugin's gwtls (= git worktree list) to print only
      # the worktree directory basename instead of the full absolute path
      unalias gwtls 2>/dev/null
      gwtls() {
        git worktree list --porcelain "$@" | awk '
          /^worktree / {
            path = $0
            sub(/^worktree /, "", path)
            n = split(path, a, "/")
            name = a[n]
          }
          /^HEAD / { sha = substr($2, 1, 10) }
          /^branch / {
            br = $2
            sub(/^refs\/heads\//, "", br)
            label = "[" br "]"
          }
          /^detached/ { label = "(detached HEAD)" }
          /^$/ {
            if (name) printf "%-40s %s %s\n", name, sha, label
            name = ""; sha = ""; label = ""
          }
          END {
            if (name) printf "%-40s %s %s\n", name, sha, label
          }
        '
      }

    '';
  };
}

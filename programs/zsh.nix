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

      # print the active system's flake provenance and compare with the current
      # worktree's git state. analog of paneherd's
      # `defaults read /Applications/PaneHerd.app/Contents/Info.plist ProjectRoot`.
      # use after `darwin-rebuild switch` to confirm the active system was built
      # from the source state you intended (see CLAUDE.md parallel-worktree
      # foot-gun).
      nix-provenance() {
        local pf=/etc/nix-config-provenance
        if [ ! -r "$pf" ]; then
          echo "no provenance at $pf — host hasn't activated since the provenance module landed, or it's not nix-darwin managed"
          return 1
        fi
        echo "== active system =="
        cat "$pf"
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
          local cur_rev cur_dirty active_rev
          cur_rev=$(git rev-parse HEAD 2>/dev/null)
          cur_dirty=""
          if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            cur_dirty="-dirty"
          fi
          echo
          echo "== current worktree =="
          echo "path=$(pwd)"
          echo "rev=$cur_rev$cur_dirty"
          echo "branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
          active_rev=$(awk -F= '/^rev=/{print $2; exit}' "$pf")
          echo
          if [ "$active_rev" = "$cur_rev$cur_dirty" ]; then
            echo "match — active system is from this worktree state"
          else
            echo "mismatch — active=$active_rev worktree=$cur_rev$cur_dirty"
            echo "  rebuild from here to make this worktree's changes live."
          fi
        fi
      }

    '';
  };
}

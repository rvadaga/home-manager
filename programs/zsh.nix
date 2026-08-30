{ config, lib, personalAppRegistry, pkgs, ... }:
let
  configurationName = config.home.sessionVariables.HM_CONFIG_NAME or "default";
  isEnabled = _: app:
    let
      profiles = app.profiles or [ ];
    in
    (app.enable or true) && (profiles == [ ] || lib.elem configurationName profiles);
  enabledApps = lib.filterAttrs isEnabled personalAppRegistry;
  appShellAliases = lib.foldl'
    (aliases: app: aliases // (app.shellAliases or { }))
    { }
    (builtins.attrValues enabledApps);
in {
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

      # k8s
      k = "kubectl";
      ctx = "kubectx";
      ns = "kubens";
    } // lib.optionalAttrs pkgs.stdenv.isDarwin appShellAliases;

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

    '';
  };
}

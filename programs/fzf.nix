{ config, ... }: {
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  programs.zsh.initContent = ''
    # fzf's widgets need a terminal because their setup restores the zle option.
    if [[ -o zle && -t 0 ]]; then
      source <(${config.programs.fzf.package}/bin/fzf --zsh)
    fi
  '';
}

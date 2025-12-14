{configs, pkgs,...}: {
  programs.kitty = {
    enable = true;

    font = {
      package = pkgs.nerd-fonts.fira-code;
      name = "FiraCode Nerd Font Mono";
    };

    themeFile = "Ayu";

    settings = {
      font_size = 15;
      adjust_line_height = 1;
      tab_bar_edge = "top";
    };

    shellIntegration = {
      enableZshIntegration = true;
    };
  };
}
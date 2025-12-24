{config, pkgs,...}: {
  programs.kitty = {
    enable = true;

    font = {
      package = pkgs.nerd-fonts.fira-code;
      name = "FiraCode Nerd Font Mono";
    };

    themeFile = "ayu";

    settings = {
      font_size = 13;
      adjust_line_height = 1;
      tab_bar_edge = "top";

      # macos-like behavior
      macos_option_as_alt = "yes";
      confirm_os_window_close = 0;
    };

    shellIntegration = {
      enableZshIntegration = true;
    };

    # macos-like keymappings
    # keyd swaps: physical ctrl→super, physical cmd→ctrl
    # - physical cmd (ctrl after keyd) → gui operations
    # - physical ctrl (super after keyd) → terminal control sequences
    keybindings = {
      # clipboard operations (physical cmd)
      "ctrl+c" = "copy_to_clipboard";
      "ctrl+v" = "paste_from_clipboard";

      # tab management (physical cmd)
      "ctrl+t" = "new_tab";
      "ctrl+shift+]" = "next_tab";
      "ctrl+shift+[" = "previous_tab";
      "ctrl+1" = "goto_tab 1";
      "ctrl+2" = "goto_tab 2";
      "ctrl+3" = "goto_tab 3";
      "ctrl+4" = "goto_tab 4";
      "ctrl+5" = "goto_tab 5";
      "ctrl+6" = "goto_tab 6";
      "ctrl+7" = "goto_tab 7";
      "ctrl+8" = "goto_tab 8";
      "ctrl+9" = "goto_tab 9";

      # window management (physical cmd)
      "ctrl+n" = "new_os_window";
      "ctrl+shift+n" = "new_window";
      "ctrl+shift+w" = "close_window";
      "ctrl+alt+]" = "next_window";
      "ctrl+alt+[" = "previous_window";

      # font size (physical cmd)
      "ctrl+equal" = "change_font_size all +2.0";
      "ctrl+plus" = "change_font_size all +2.0";
      "ctrl+minus" = "change_font_size all -2.0";
      "ctrl+0" = "change_font_size all 0";

      # utility (physical cmd)
      "ctrl+f" = "show_scrollback";
      "ctrl+shift+," = "edit_config_file";
      "ctrl+," = "edit_config_file";
      "ctrl+q" = "quit";
      "ctrl+shift+f" = "toggle_fullscreen";

      # line navigation (physical cmd)
      "ctrl+left" = "send_text all \\x01";  # beginning of line
      "ctrl+right" = "send_text all \\x05";  # end of line

      # clear screen (physical cmd)
      "ctrl+k" = "clear_terminal reset active";
      "ctrl+l" = "clear_terminal scrollback active";

      # terminal control sequences (physical ctrl → super after keyd)
      "super+c" = "send_text all \\x03";  # ctrl-c (interrupt)
      "super+d" = "send_text all \\x04";  # ctrl-d (eof)
      "super+u" = "send_text all \\x15";  # ctrl-u (delete line)
      "super+w" = "send_text all \\x17";  # ctrl-w (delete word)
      "super+a" = "send_text all \\x01";  # ctrl-a (beginning of line)
      "super+e" = "send_text all \\x05";  # ctrl-e (end of line)
      "super+k" = "send_text all \\x0b";  # ctrl-k (kill to end)
      "super+r" = "send_text all \\x12";  # ctrl-r (reverse search)
    };
  };
}

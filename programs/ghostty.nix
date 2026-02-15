{config, pkgs,...}: {
  programs.ghostty = {
    enable = true;

    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-size = 13;
      theme = "Ayu";

      # window
      confirm-close-surface = false;
      window-decoration = true;
      gtk-tabs-location = "top";

      # keybindings - macos-like behavior
      # keyd swaps: physical ctrl→super, physical cmd→ctrl

      # clipboard (physical cmd)
      keybind = [
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"

        # tab management (physical cmd)
        "ctrl+t=new_tab"
        "ctrl+shift+]=next_tab"
        "ctrl+shift+[=previous_tab"
        "ctrl+1=goto_tab:1"
        "ctrl+2=goto_tab:2"
        "ctrl+3=goto_tab:3"
        "ctrl+4=goto_tab:4"
        "ctrl+5=goto_tab:5"
        "ctrl+6=goto_tab:6"
        "ctrl+7=goto_tab:7"
        "ctrl+8=goto_tab:8"
        "ctrl+9=goto_tab:9"

        # window/split management (physical cmd)
        "ctrl+n=new_window"
        "ctrl+shift+n=new_split:right"
        "ctrl+shift+w=close_surface"

        # font size (physical cmd)
        "ctrl+equal=increase_font_size:2"
        "ctrl+plus=increase_font_size:2"
        "ctrl+minus=decrease_font_size:2"
        "ctrl+zero=reset_font_size"

        # utility (physical cmd)
        "ctrl+shift+f=toggle_fullscreen"
        "ctrl+q=quit"

        # clear screen (physical cmd)
        "ctrl+k=reset"
        "ctrl+l=clear_screen"

        # terminal control sequences (physical ctrl → super after keyd)
        "super+c=text:\\x03"
        "super+d=text:\\x04"
        "super+u=text:\\x15"
        "super+w=text:\\x17"
        "super+a=text:\\x01"
        "super+e=text:\\x05"
        "super+k=text:\\x0b"
        "super+r=text:\\x12"
      ];
    };

    enableZshIntegration = true;
  };
}

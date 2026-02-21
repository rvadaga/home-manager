{config, pkgs, lib,...}:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  programs.ghostty = {
    enable = true;
    # ghostty nixpkg only supports linux; on macOS install via DMG
    package = lib.mkIf isDarwin null;

    settings = {
      font-family = "SF Mono";
      font-size = 14;
      font-style = "Semibold";
      theme = "Starlight";

      # window
      confirm-close-surface = false;
      window-decoration = true;
      working-directory = "home";
      window-inherit-working-directory = false;
      window-save-state = "always";
    } // lib.optionalAttrs (!isDarwin) {
      gtk-tabs-location = "top";

      # keybindings for linux only (keyd swaps: physical ctrl→super, physical cmd→ctrl)
      # on macOS, ghostty's native keybindings are used instead
      keybind = [
        # clipboard (physical cmd → ctrl after keyd)
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
        "ctrl+d=new_split:right"
        "ctrl+shift+d=new_split:down"
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

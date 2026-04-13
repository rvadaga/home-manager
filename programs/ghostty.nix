{config, pkgs, lib,...}:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  programs.ghostty = {
    enable = true;
    # on macOS: install via DMG (nix package doesn't support darwin)
    # on linux: use tip channel from ghostty flake for latest features
    package = if isDarwin then null else pkgs.ghostty-tip;

    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-size = 14;
      font-style = "Semibold";
      theme = "Starlight";

      # bell — disable audible bell, keep notification features
      bell-features = "no-audio";

      # clipboard
      clipboard-paste-protection = false;

      # window
      confirm-close-surface = true;
      window-decoration = true;
      working-directory = "home";
      window-inherit-working-directory = false;
      tab-inherit-working-directory = false;
      split-inherit-working-directory = true;
      window-save-state = "always";

      # undo close — 60s window to recover closed tabs/splits/windows
      undo-timeout = "60s";
    } // lib.optionalAttrs isDarwin {
      # cmd+z works natively; add browser-style cmd+shift+t as well
      keybind = [
        "cmd+shift+t=undo"
      ];
    } // lib.optionalAttrs (!isDarwin) {
      font-size = 12;
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

        # undo close (physical cmd+shift+t / cmd+z)
        "ctrl+shift+t=undo"

        # window/split management (physical cmd)
        "ctrl+n=new_window"
        "ctrl+d=new_split:right"
        "ctrl+shift+d=new_split:down"
        "ctrl+w=close_surface"

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

        # search (physical cmd+f → ctrl+f after keyd)
        "ctrl+f=start_search"
        "ctrl+g=navigate_search:next"
        "ctrl+shift+g=navigate_search:previous"

        # let meta+alt+arrows pass through to WM for window tiling
        # keyd sends Meta+Alt (not Ctrl+Alt) for physical ctrl+opt combos
        "super+alt+left=unbind"
        "super+alt+right=unbind"
      ];
    };

    enableZshIntegration = true;
  };
}

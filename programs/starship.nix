{ config, pkgs, lib, ... }:
let
  # powerline rounded glyphs (U+E0B4 , U+E0B6 )
  # IMPORTANT: do NOT paste these characters literally — tools (including claude code's
  # Write tool) silently strip private-use-area unicode. use builtins.fromJSON to
  # generate them from codepoints at build time instead.
  rc = builtins.fromJSON ''"\ue0b4"'';  # right cap  (closes a segment)
  lc = builtins.fromJSON ''"\ue0b6"'';  # left cap   (opens a segment)
in {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      # gruvbox rainbow — two-prompt layout
      # left: identity -> location -> git (continuous powerline)
      # right: native RPROMPT via right_format (auto-hides on overflow)
      format = lib.concatStrings [
        # left — identity (orange)
        "[${lc}](color_orange)"
        "$os"
        "$username"
        "[${rc}](bg:color_yellow fg:color_orange)"
        # left — location (yellow)
        "$directory"
        "[${rc}](fg:color_yellow bg:color_aqua)"
        # left — git (aqua)
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_status"
        "[${rc}](fg:color_aqua)"
        # line 2
        "$line_break"
        "$status"
        "$character"
      ];

      right_format = lib.concatStrings [
        # languages (blue pills)
        "$c"
        "$cpp"
        "$rust"
        "$java"
        "$python"
        # dev env (aqua pills)
        "$direnv"
        "$nix_shell"
        # infra (purple pills)
        "$kubernetes"
        "$docker_context"
        "$container"
        # perf (bg3 pill)
        "$cmd_duration"
        # clock (bg1 pill)
        "$time"
      ];

      palette = "gruvbox_dark";

      palettes.gruvbox_dark = {
        color_fg0 = "#fbf1c7";
        color_bg1 = "#3c3836";
        color_bg3 = "#665c54";
        color_blue = "#458588";
        color_aqua = "#689d6a";
        color_green = "#98971a";
        color_orange = "#d65d0e";
        color_purple = "#b16286";
        color_red = "#cc241d";
        color_yellow = "#d79921";
      };

      os = {
        disabled = false;
        style = "bg:color_orange fg:color_fg0";
        symbols = {
          Macos = "󰀵";
          NixOS = "";
          Linux = "󰌽";
          Windows = "󰍲";
          Ubuntu = "󰕈";
          Fedora = "󰣛";
          Arch = "󰣇";
          Debian = "󰣚";
          Alpine = "";
        };
      };

      username = {
        show_always = true;
        style_user = "bg:color_orange fg:color_fg0";
        style_root = "bg:color_orange fg:color_fg0";
        format = "[ $ssh_symbol$user ]($style)";
      };

      directory = {
        style = "fg:color_fg0 bg:color_yellow";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          Documents = "󰈙 ";
          Downloads = " ";
          Music = "󰝚 ";
          Pictures = " ";
          Developer = "󰲋 ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:color_aqua";
        format = "[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)";
      };

      git_commit = {
        style = "bg:color_aqua";
        format = "[[ $hash$tag ](fg:color_fg0 bg:color_aqua)]($style)";
        only_detached = true;
        tag_disabled = false;
        tag_symbol = " 🏷 ";
      };

      git_state = {
        style = "bg:color_aqua";
        format = "[[ $state( $progress_current/$progress_total) ](fg:color_fg0 bg:color_aqua)]($style)";
      };

      git_status = {
        style = "bg:color_aqua";
        format = "[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)";
        # p10k-style symbols with counts
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇡\${ahead_count}⇣\${behind_count}";
        up_to_date = "=";
        conflicted = "~\${count}";
        stashed = "*\${count}";
        staged = "+\${count}";
        modified = "!\${count}";
        untracked = "?\${count}";
        deleted = "✘\${count}";
        renamed = "»\${count}";
      };

      status = {
        disabled = false;
        format = "[$symbol$status ]($style)";
        symbol = "✘ ";
        style = "fg:color_red";
      };

      # right side — language pills (blue)
      c = {
        symbol = " ";
        style = "bg:color_blue";
        format = " [${lc}](fg:color_blue)[ $symbol($version) ](fg:color_fg0 bg:color_blue)[${rc}](fg:color_blue)";
      };

      cpp = {
        symbol = " ";
        style = "bg:color_blue";
        format = " [${lc}](fg:color_blue)[ $symbol($version) ](fg:color_fg0 bg:color_blue)[${rc}](fg:color_blue)";
      };

      rust = {
        symbol = "";
        style = "bg:color_blue";
        format = " [${lc}](fg:color_blue)[ $symbol ($version) ](fg:color_fg0 bg:color_blue)[${rc}](fg:color_blue)";
      };

      java = {
        symbol = "";
        style = "bg:color_blue";
        format = " [${lc}](fg:color_blue)[ $symbol ($version) ](fg:color_fg0 bg:color_blue)[${rc}](fg:color_blue)";
      };

      python = {
        symbol = "";
        style = "bg:color_blue";
        format = " [${lc}](fg:color_blue)[ $symbol ($version) ](fg:color_fg0 bg:color_blue)[${rc}](fg:color_blue)";
      };

      # right side — dev env pills (aqua)
      direnv = {
        disabled = false;
        style = "bg:color_aqua";
        format = " [${lc}](fg:color_aqua)[ $loaded/$allowed ](fg:color_fg0 bg:color_aqua)[${rc}](fg:color_aqua)";
      };

      nix_shell = {
        symbol = " ";
        style = "bg:color_aqua";
        format = " [${lc}](fg:color_aqua)[ $symbol$state ](fg:color_fg0 bg:color_aqua)[${rc}](fg:color_aqua)";
      };

      # right side — infra pills (purple)
      kubernetes = {
        disabled = false;
        symbol = "☸ ";
        style = "bg:color_purple";
        format = " [${lc}](fg:color_purple)[ $symbol$namespace ](fg:color_fg0 bg:color_purple)[${rc}](fg:color_purple)";
        contexts = [
          { context_pattern = "gke_etsy-.*_us-central1_(?P<name>.*)"; context_alias = "$name"; }
          { context_pattern = "vespa-cloud-(?P<env>[^_]+)_(?P<name>.*)"; context_alias = "vespa:$env/$name"; }
        ];
      };

      docker_context = {
        symbol = "";
        style = "bg:color_purple";
        format = " [${lc}](fg:color_purple)[ $symbol ($context) ](fg:color_fg0 bg:color_purple)[${rc}](fg:color_purple)";
      };

      container = {
        disabled = false;
        symbol = "⬡ ";
        style = "bg:color_purple";
        format = " [${lc}](fg:color_purple)[ $symbol$name ](fg:color_fg0 bg:color_purple)[${rc}](fg:color_purple)";
      };

      # right side — perf pill (bg3)
      cmd_duration = {
        style = "bg:color_bg3";
        format = " [${lc}](fg:color_bg3)[  $duration ](fg:color_fg0 bg:color_bg3)[${rc}](fg:color_bg3)";
        min_time = 3000;
      };

      # right side — clock pill (bg1)
      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_bg1";
        format = " [${lc}](fg:color_bg1)[  $time ](fg:color_fg0 bg:color_bg1)[${rc}](fg:color_bg1)";
      };

      line_break.disabled = false;

      character = {
        disabled = false;
        success_symbol = "[❯](bold fg:color_green)";
        error_symbol = "[❯](bold fg:color_red)";
        vimcmd_symbol = "[❮](bold fg:color_green)";
        vimcmd_replace_one_symbol = "[❮](bold fg:color_purple)";
        vimcmd_replace_symbol = "[❮](bold fg:color_purple)";
        vimcmd_visual_symbol = "[❮](bold fg:color_yellow)";
      };
    };
  };
}

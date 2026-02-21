{ config, pkgs, lib, ... }: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # blank line before each prompt
      add_newline = true;
      command_timeout = 2000;

      # prompt format: 2-line layout
      # line 1 left: os icon, directory, git
      # line 1 right: k8s, python, nix, cmd_duration, time
      # line 2: prompt character
      format = lib.concatStrings [
        "$os"
        "$directory"
        "$git_branch"
        "$git_status"
        "$fill"
        "$kubernetes"
        "$python"
        "$nix_shell"
        "$cmd_duration"
        "$time"
        "\n"
        "$character"
      ];

      # os icon
      os = {
        disabled = false;
        style = "bold white";
        symbols = {
          Macos = " ";
          NixOS = " ";
          Linux = " ";
        };
      };

      # directory (full path)
      directory = {
        style = "bold cyan";
        truncation_length = 0;
      };

      # git branch
      git_branch = {
        style = "bold purple";
        format = "[$symbol$branch(:$remote_branch)]($style) ";
        symbol = " ";
      };

      # git status
      git_status = {
        style = "bold red";
        format = "([$all_status$ahead_behind]($style) )";
      };

      # fill between left and right
      fill = {
        symbol = " ";
      };

      # prompt character
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      # command duration (show if > 3 seconds)
      cmd_duration = {
        style = "bold yellow";
        format = "[$duration]($style) ";
        min_time = 3000;
      };

      # time
      time = {
        disabled = false;
        style = "bold dimmed white";
        format = "[$time]($style)";
        time_format = "%H:%M";
      };

      # kubernetes (shorten gke context names to last segment)
      kubernetes = {
        disabled = false;
        style = "bold blue";
        format = "[$symbol$context(/$namespace)]($style) ";
        symbol = "☸ ";
        contexts = [
          { context_pattern = "gke_etsy-.*_us-central1_(?P<name>.*)"; context_alias = "$name"; }
          { context_pattern = "vespa-cloud-(?P<env>[^_]+)_(?P<name>.*)"; context_alias = "vespa:$env/$name"; }
        ];
      };

      # python virtualenv
      python = {
        style = "bold yellow";
        format = "[$symbol$virtualenv]($style) ";
        symbol = " ";
      };

      # nix shell indicator
      nix_shell = {
        style = "bold blue";
        format = "[$symbol$state]($style) ";
        symbol = " ";
      };

      # status (for exit codes)
      status = {
        disabled = false;
        style = "bold red";
      };
    };
  };
}

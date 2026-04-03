{ config, pkgs, lib, ... }: {
  imports = [
    ../programs/claude.nix
    ../programs/fzf.nix
    ../programs/ghostty.nix
    ../programs/kitty.nix
    ../programs/neovim.nix
    ../programs/npm.nix
    ../programs/starship.nix
    ../programs/zsh.nix
  ];

  # claude configuration
  claude.settingsPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-base.json)) ];
  home = {
    file = {
      ".claude/CLAUDE.md".text = builtins.readFile ../dotfiles/claude/CLAUDE-base.md;
      ".claude/skills/sync-claude-settings/SKILL.md".source = ../dotfiles/claude/skills/sync-claude-settings/SKILL.md;
      ".claude/skills/diff-claude-settings/SKILL.md".source = ../dotfiles/claude/skills/diff-claude-settings/SKILL.md;
      ".claude/skills/clean-plugins/SKILL.md".source = ../dotfiles/claude/skills/clean-plugins/SKILL.md;
      ".claude/commands/notes.md".source = ../dotfiles/claude/commands/notes.md;
    };

    packages = [
      # shell and terminal
      pkgs.bash
      pkgs.nerd-fonts.fira-code

      # system utilities
      pkgs.htop
      pkgs.procs
      pkgs.tree
      pkgs.curl
      pkgs.unstable.openssh
      pkgs.unstable.tz
      pkgs._1password-cli

      # file viewers and search
      pkgs.ripgrep
      pkgs.bat
      pkgs.glow
      pkgs.jless
      pkgs.difftastic

      # json/yaml/xml tools
      pkgs.jq
      pkgs.yq-go
      (pkgs.writeShellScriptBin "xless" ''
        yq -p xml -o json . $1 | jless
      '')

      # build and task runners
      pkgs.just
      pkgs.go-jsonnet

      # benchmarking
      pkgs.hyperfine

      # network tools
      pkgs.cloudflare-speed-cli

      # fun stuff
      pkgs.fortune
      pkgs.cowsay
      pkgs.lolcat
      pkgs.neofetch

      # version control
      pkgs.gh

      # kubernetes
      pkgs.kubectl
      pkgs.kubectx
      pkgs.kubernetes-helm

      # cloud providers
      (pkgs.unstable.google-cloud-sdk.withExtraComponents [
        pkgs.unstable.google-cloud-sdk.components.gke-gcloud-auth-plugin
      ])

      # infrastructure as code
      (pkgs.unstable.terraform.overrideAttrs (old: {
        doCheck = false;
      }))

      # grpc tools
      pkgs.grpcurl
      pkgs.grpcui
      pkgs.protobuf

      # documentation
      pkgs.asciidoctor-with-extensions

      # nix tools
      pkgs.nix-direnv

      # programming languages: java
      pkgs.unstable.temurin-bin  # java 25
      pkgs.maven

      # programming languages: javascript/typescript
      pkgs.unstable.nodejs_24

      # programming languages: python
      pkgs.poetry
      pkgs.unstable.uv

      # programming languages: rust
      pkgs.rustup

      # programming languages: zig
      pkgs.zig
    ];

    sessionPath = [
      "$HOME/.local/bin"
    ];

    sessionVariables = {
      SCRATCHPAD_DIR = lib.mkDefault "$HOME/development/scratchpad";
      BAT_THEME = "Nord";
      JAVA_HOME = "${pkgs.unstable.temurin-bin}";
      MAVEN_OPTS = "-Djavax.net.ssl.trustStore=${pkgs.unstable.temurin-bin}/lib/openjdk/lib/security/cacerts";
      OP_BIOMETRIC_UNLOCK_ENABLED = "true";
      # nix-managed terminfo (ghostty, kitty) lives in the profile — tell ncurses where to find it
      TERMINFO_DIRS = "$HOME/.nix-profile/share/terminfo:/usr/share/terminfo";
      # disable flickering in claude code terminal output
      CLAUDE_CODE_NO_FLICKER = "1";
    };
  };

  # required to autoload fonts from packages installed via Home Manager
  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "Fira Code Nerd Font" ];
      };
    };
  };

  programs = {
    # home manager
    home-manager = {
      enable = true;
    };

    # development environment
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      config = {
        global = {
          warn_timeout = "0s";
        };
      };
    };

    # version control
    git = {
      enable = true;
      package = pkgs.unstable.git;

      # signing
      signing = {
        key = null;
        signByDefault = true;
      };

      # configuration
      settings = {
        # identity
        user = {
          name = "Rahul Vadaga";
          email = lib.mkDefault "rahul.vadaga@gmail.com";
        };

        # aliases
        alias = {
          rpull = "pull --rebase --stat";
        };

        branch = {
          sort = "-committerdate";
        };

        column = {
          ui = "auto";
        };

        core = {
          fsmonitor = true;
          untrackedCache = true;
        };

        diff = {
          algorithm = "histogram";
          cordMoved = "plain";
          menmonicPrefix = true;
          renames = true;
        };

        fetch = {
          prune = true;
          pruneTags = true;
          all = true;
        };

        init = {
          defaultBranch = "main";
        };

        merge = {
          conflictStyle = "diff3";
        };

        push = {
          default = "simple";
          autoSetupRemote = true;
          followTags = true;
        };

        rebase = {
          autoSquash = true;
          autoStash = true;
        };

        rerere = {
          enabled = true;
          autoupdate = true;
        };

        tag = {
          sort = "version:refname";
        };
      };
    };

    gpg = {
      enable = true;
      homedir = "${config.home.homeDirectory}/.gnupg";
    };

    # shell
    zsh = {
      shellAliases = {
        dph = "cd $HOME/development/paneherd";
        dvsp = "cd $HOME/development/vespa";
      };
    };
  };

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      download-buffer-size = 134217728;  # 128 MB
    };
  };
}

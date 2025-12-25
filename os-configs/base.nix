{ config, pkgs, lib, ... }: {
  imports = [
    ../programs/claude.nix
    ../programs/fzf.nix
    ../programs/kitty.nix
    ../programs/neovim.nix
    ../programs/npm.nix
    ../programs/zsh.nix
  ];

  # claude configuration
  claude.settingsPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-base.json)) ];
  claude.settingsLocalPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings.local-base.json)) ];

  home = {
    file = {
      ".claude/CLAUDE.md".text = builtins.readFile ../dotfiles/claude/CLAUDE-base.md;
    };

    packages = [
      # shell and terminal
      pkgs.bash
      pkgs.zsh-powerlevel10k
      pkgs.starship
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
      pkgs.jless
      pkgs.difftastic

      # json/yaml/xml tools
      pkgs.jq
      pkgs.yq
      (pkgs.writeShellScriptBin "xless" ''
        xq . $1 | jless
      '')

      # build and task runners
      pkgs.just

      # benchmarking
      pkgs.hyperfine

      # fun stuff
      pkgs.fortune
      pkgs.cowsay
      pkgs.lolcat

      # version control
      pkgs.gh

      # kubernetes
      pkgs.kubectl
      pkgs.kubectx

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

      # development environments
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
      BAT_THEME = "Nord";
      JAVA_HOME = "${pkgs.unstable.temurin-bin}";
      MAVEN_OPTS = "-Djavax.net.ssl.trustStore=${pkgs.unstable.temurin-bin}/lib/openjdk/lib/security/cacerts";
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
    };

    # version control
    git = {
      enable = true;
      package = pkgs.unstable.git;

      # identity
      userName = "Rahul Vadaga";
      userEmail = lib.mkDefault "rahul.vadaga@gmail.com";

      # signing
      signing = {
        key = null;
        signByDefault = true;
      };

      # aliases
      aliases = {
        rpull = "pull --rebase --stat";
      };

      # configuration
      extraConfig = {
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
        dvsp = "cd $HOME/development/vespa";
      };
    };
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      download-buffer-size = 134217728;  # 128 MB
    };
  };
}

{ config, pkgs, lib, osConfig ? null, inputs, ... }:
let
  ghStack = pkgs.callPackage ../packages/gh-stack.nix { };
  readInstructions = bannerPath: bodyPath:
    lib.concatStringsSep "\n\n" (
      lib.optionals config.llmInstructions.includePersonalRepoBanner [
        (builtins.readFile bannerPath)
      ]
      ++ [ (builtins.readFile bodyPath) ]
    );
  baseInstructions = readInstructions
    ../dotfiles/claude/CLAUDE-personal-scope.md
    ../dotfiles/claude/CLAUDE-base.md;
  # preserve app-owned entries such as .system by managing only shared children.
  codexSkillFiles = lib.mapAttrs' (skillName: _:
    lib.nameValuePair ".codex/skills/${skillName}" {
      source = ../dotfiles/claude/skills + "/${skillName}";
    }
  ) (lib.filterAttrs (_: fileType: fileType == "directory")
    (builtins.readDir ../dotfiles/claude/skills));
in {
  imports = [
    ../os-configs/llm-instructions.nix
    ../programs/claude.nix
    ../programs/codex.nix
    ../programs/fzf.nix
    ../programs/ghostty.nix
    ../programs/kitty.nix
    ../programs/neovim.nix
    ../programs/npm.nix
    ../programs/starship.nix
    ../programs/zsh.nix
  ];

  # claude and codex configuration
  claude.settingsPieces = [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-base.json)) ];
  codex.settingsPieces = [ (builtins.fromTOML (builtins.readFile ../dotfiles/codex/settings-base.toml)) ];
  home = {
    file = {
      ".codex/AGENTS.md".text = baseInstructions;
      ".claude/CLAUDE.md".text = baseInstructions;
      ".claude/skills/sync-claude-settings/SKILL.md".source = ../dotfiles/claude/skills/sync-claude-settings/SKILL.md;
      ".claude/skills/diff-claude-settings/SKILL.md".source = ../dotfiles/claude/skills/diff-claude-settings/SKILL.md;
      ".claude/skills/clean-plugins/SKILL.md".source = ../dotfiles/claude/skills/clean-plugins/SKILL.md;
      ".claude/skills/bootstrap-plugins/SKILL.md".source = ../dotfiles/claude/skills/bootstrap-plugins/SKILL.md;
      ".claude/skills/nix-rebuild/SKILL.md".source = ../dotfiles/claude/skills/nix-rebuild/SKILL.md;
      ".claude/skills/ship-config/SKILL.md".source = ../dotfiles/claude/skills/ship-config/SKILL.md;
      ".claude/skills/github-stacked-prs/SKILL.md".source = ../dotfiles/claude/skills/github-stacked-prs/SKILL.md;
      ".claude/skills/slack-mcp-formatting/SKILL.md".source = ../dotfiles/claude/skills/slack-mcp-formatting/SKILL.md;
      ".claude/skills/editing-google-docs/SKILL.md".source = ../dotfiles/claude/skills/editing-google-docs/SKILL.md;
      ".claude/skills/editing-google-slides/SKILL.md".source = ../dotfiles/claude/skills/editing-google-slides/SKILL.md;
      # notes skill: base covers the general llm-wiki vaults (personal-software,
      # oss-vespa); a downstream config can compose into the same skill dir by
      # adding references/work-vault.md (registry entry for its work vault).
      ".claude/skills/notes/SKILL.md".source = ../dotfiles/claude/skills/notes/SKILL.md;
      ".claude/commands/wt-name.md".source = ../dotfiles/claude/commands/wt-name.md;

      # nix-provenance: print the active system's flake provenance (written to
      # /etc/nix-config-provenance by darwin/provenance.nix at activation) and
      # compare with the current worktree's git state. use after `darwin-rebuild
      # switch` to confirm the active system was built from the source state
      # you intended (see CLAUDE.md parallel-worktree foot-gun).
      #
      # bash script (not a zsh function) so it works in any shell, including
      # the claude-code bash harness. mirrors the ecurl/esudo pattern.
      ".local/bin/nix-provenance" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # repo-awareness: only suggest "rebuild from here" when pwd is itself
          # a nix-config flake repo (flake.nix at its top). otherwise the
          # rev/narHash in the provenance file belongs to a different flake
          # and pwd's git state isn't a rebuild-actionable signal.
          set -uo pipefail

          pf=/etc/nix-config-provenance
          if [ ! -r "$pf" ]; then
            echo "no provenance at $pf — host hasn't activated since the provenance module landed, or it's not nix-darwin managed"
            exit 1
          fi
          echo "== active system =="
          cat "$pf"

          if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            exit 0
          fi

          cur_rev=$(git rev-parse HEAD 2>/dev/null)
          cur_dirty=""
          if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            cur_dirty="-dirty"
          fi
          repo_top=$(git rev-parse --show-toplevel 2>/dev/null)
          is_flake_repo=no
          if [ -n "$repo_top" ] && [ -f "$repo_top/flake.nix" ]; then
            is_flake_repo=yes
          fi
          cur_origin=$(git config --get remote.origin.url 2>/dev/null)
          active_rev=$(awk -F= '/^rev=/{print $2; exit}' "$pf")

          echo
          echo "== current worktree =="
          echo "path=$(pwd)"
          echo "rev=$cur_rev$cur_dirty"
          echo "branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
          echo "origin=''${cur_origin:-<none>}"
          echo

          if [ "$is_flake_repo" != yes ]; then
            echo "(pwd is not a nix-config flake repo — comparison is informational only, not a rebuild signal)"
            exit 0
          fi

          if [ "$active_rev" = "$cur_rev$cur_dirty" ]; then
            echo "match — active system is from this flake repo at this rev"
          else
            echo "mismatch — active=$active_rev worktree=$cur_rev$cur_dirty"
            echo "  if this repo built the active system: rebuild from here to make your changes live."
            echo "  if this repo did NOT build the active system (different flake): no rebuild needed from here."
          fi
        '';
      };
    } // codexSkillFiles;

    packages = [
      # shell and terminal
      pkgs.bash
      pkgs.nerd-fonts.fira-code
      pkgs.fira

      # system utilities
      pkgs.btop
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
      (pkgs.writeShellScriptBin "claude-strip-images" ''
        exec ${pkgs.python3}/bin/python3 ${../scripts/claude-strip-images.py} "$@"
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
      pkgs.fastfetch

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
      pkgs.gws

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
      # test_read_text_file reads an arbitrary text file out of the real
      # /nix/store and asserts "Error" is absent from the tool output — but it
      # matches against the file's own contents. macos builds run unsandboxed
      # (nix sandbox defaults to false on darwin), so the test sees the host
      # store and trips over any file containing the word, e.g. a minified
      # highlight.js bundle. impure upstream test; the other 281 still run.
      (pkgs.unstable.mcp-nixos.overrideAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [ "test_read_text_file" ];
      }))

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

  # github cli discovers extensions under its xdg data directory. keep the
  # official stack binary in that layout so `gh stack` dispatches to it.
  xdg.dataFile."gh/extensions/gh-stack".source = "${ghStack}/bin";

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
    # home manager (disabled under nix-darwin which manages activation itself)
    home-manager = {
      enable = lib.mkDefault (osConfig == null);
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
        key = lib.mkDefault null;
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

  # nix settings only in standalone home-manager (nix-darwin owns these at system level)
  nix = lib.mkIf (osConfig == null) {
    package = pkgs.nix;
    settings = import ../shared/nix-settings.nix;
  };
}

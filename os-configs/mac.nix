{ config, pkgs, lib, ... }: {
  # claude configuration
  claude.settingsPieces = lib.mkAfter [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-mac.json)) ];
  home = {
    file = {
      ".codex/AGENTS.md".text = lib.mkAfter (
        "\n\n" + builtins.readFile ../dotfiles/codex/AGENTS-mac.md
      );

      ".claude/CLAUDE.md".text = lib.mkAfter (
        "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-mac.md
      );

      # gpg-agent config (services.gpg-agent is systemd-only, not available on mac)
      ".gnupg/gpg-agent.conf".text = ''
        pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
        default-cache-ttl 28800
        max-cache-ttl 28800
      '';

      # git: /bin/sh shim in front of the nix git so the claude desktop app
      # can detect git. macos (amfid/syspolicyd) denies a third-party gui app
      # binary direct exec of adhoc-signed nix binaries (posix_spawn EACCES →
      # "Git is required for local sessions" banner). a shebang script makes
      # the app exec apple-signed /bin/sh instead; terminals still get the
      # nix git through the same shim. ~/.local/bin precedes the profile
      # dirs in PATH.
      ".local/bin/git" = {
        executable = true;
        text = ''
          #!/bin/sh
          exec ${config.home.profileDirectory}/bin/git "$@"
        '';
      };
    };

    packages = [
      pkgs.unstable.coreutils-prefixed  # g-prefixed gnu coreutils (gpaste, gstat, etc.)
      pkgs.pinentry_mac
    ];
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = "yes";
      };
    };
    includes = [
      "~/.step/ssh/includes"
    ];
  };
}

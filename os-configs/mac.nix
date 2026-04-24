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
    };

    packages = [
      pkgs.unstable.coreutils-prefixed  # g-prefixed gnu coreutils (gpaste, gstat, etc.)
      pkgs.pinentry_mac
    ];
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      IgnoreUnknown UseKeychain
    '';
    matchBlocks = {
      "*" = {
        extraOptions = {
          AddKeysToAgent = "yes";
          IdentitiesOnly = "yes";
          UseKeychain = "yes";
        };
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
    includes = [
      "~/.step/ssh/includes"
    ];
  };
}

{ config, pkgs, lib, ... }:
let
  osInstructions = "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-mac.md;
in {
  # claude configuration
  claude.settingsPieces = lib.mkAfter [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-mac.json)) ];
  home = {
    file = {
      ".codex/AGENTS.md".text = lib.mkAfter osInstructions;

      ".claude/CLAUDE.md".text = lib.mkAfter osInstructions;

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

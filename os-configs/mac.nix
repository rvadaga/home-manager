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

      # claude and codex capture path through marked login-shell probes, then
      # direct-spawn git from their gui processes. macos 26 intermittently
      # blocks the ad-hoc-signed nix git at that boundary with eacces. expose
      # apple's platform-signed git only to those probes; regular shells keep
      # using the nix-managed git.
      ".local/libexec/gui-git/git".source =
        config.lib.file.mkOutOfStoreSymlink "/usr/bin/git";

      ".local/libexec/stay-awake" = {
        source = ../scripts/stay-awake.zsh;
        executable = true;
      };

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

  programs.zsh.initContent = lib.mkAfter ''
    function stay-awake() {
      sudo /bin/zsh "$HOME/.local/libexec/stay-awake" "$@"
    }

    if [[ "$CLAUDE_DESKTOP_RESOLVING_ENVIRONMENT" = 1 || "$CODEX_SHELL" = 1 ]]; then
      gui_git_dir="$HOME/.local/libexec/gui-git"
      if [[ ":$PATH:" != *":$gui_git_dir:"* ]]; then
        export PATH="$gui_git_dir:$PATH"
      fi
      unset gui_git_dir
    fi
  '';

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

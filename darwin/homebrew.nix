{ lib, ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # nix-darwin maps cleanup = "uninstall"/"zap" to a --force-cleanup flag
      # (modules/homebrew.nix), which homebrew dropped in 5.x — the modern
      # spelling is `brew bundle cleanup --force`. with the stale flag still
      # emitted, `brew bundle` exits 1 on "invalid option: --force-cleanup" and
      # aborts activation BEFORE the home-manager step, so user-level config
      # (CLAUDE.md, skills, dotfiles) silently never applies while
      # /run/current-system still moves forward.
      #
      # "none" is the only value producing a valid command on homebrew 5.x.
      # casks in the brewfile are still installed; what's lost is zapping casks
      # that are NOT listed. restore "zap" once nix-darwin emits the new flags.
      cleanup = lib.mkDefault "none";
    };

    # masApps disabled — mas 2.x CLI is incompatible with nix-darwin's brew bundle integration
    # install manually: Monosnap (App Store ID 540348655)
  };
}

{ config, lib, pkgs, ... }:
let
  user = config.users.users.${config.system.primaryUser};

  # audit cask artifacts that `brew bundle` structurally cannot see.
  #
  # `brew bundle` checks the caskroom RECEIPT, never the artifact. a cask stays
  # "installed" after its .app is deleted from /Applications, and after
  # homebrew's periodic auto-cleanup reaps the payload of a binary-artifact
  # cask (whose binary lives INSIDE the caskroom and is symlinked into
  # /opt/homebrew/bin). both states survive every `darwin-rebuild switch`
  # untouched — activation cheerfully prints "Using <cask>" while the app is
  # gone — so nix-darwin can never self-heal them. hence an explicit check.
  #
  # observed both: ghostty (app deleted, dangling caskroom back-ref) and codex
  # (payload reaped by cleanup, dangling binstub in /opt/homebrew/bin).
  brewHealth = pkgs.writeShellScriptBin "brew-health" ''
    set -uo pipefail

    brew=/opt/homebrew/bin/brew
    caskroom=/opt/homebrew/Caskroom

    if [ ! -x "$brew" ]; then
      echo "homebrew not installed at $brew — nothing to check"
      exit 0
    fi

    repair=no
    case "''${1:-}" in
      --repair) repair=yes ;;
      "") ;;
      *) echo "usage: brew-health [--repair]" >&2; exit 2 ;;
    esac

    broken=""
    for c in $("$brew" list --cask 2>/dev/null); do
      bad=""
      for v in "$caskroom/$c"/*/; do
        [ -d "$v" ] || continue

        # payload directory emptied by `brew cleanup` — binary-artifact casks
        # keep their executable here, so this leaves a dangling binstub.
        if [ -z "$(ls -A "$v" 2>/dev/null)" ]; then
          bad="empty payload"
          continue
        fi

        # homebrew moves .app artifacts to /Applications and leaves a symlink
        # back-reference. deleting the app makes that reference dangle.
        while IFS= read -r l; do
          [ -e "$l" ] || bad="missing app"
        done < <(find "$v" -maxdepth 1 -name '*.app' -type l 2>/dev/null)
      done

      if [ -n "$bad" ]; then
        echo "broken cask: $c ($bad)"
        broken="$broken $c"
      fi
    done

    # binstubs pointing into a reaped caskroom payload
    for b in /opt/homebrew/bin/*; do
      [ -L "$b" ] || continue
      [ -e "$b" ] && continue
      echo "dangling binstub: $b -> $(readlink "$b")"
    done

    if [ -z "$broken" ]; then
      echo "brew-health: all casks intact"
      exit 0
    fi

    if [ "$repair" != yes ]; then
      echo
      echo "run 'brew-health --repair' to reinstall the casks above"
      echo "(this re-downloads them; sizes vary)"
      exit 1
    fi

    rc=0
    for c in $broken; do
      echo "==> reinstalling $c"
      HOMEBREW_NO_AUTO_UPDATE=1 "$brew" reinstall --cask "$c" || { echo "failed: $c" >&2; rc=1; }
    done
    exit $rc
  '';
in {
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

    casks = lib.mkDefault [
      "1password"
      "bettermouse"
      "bettertouchtool"
      "chatgpt"
      "claude"
      "docker-desktop"
      "ghostty"
      "google-chrome"
      "google-drive"
      "itsycal"
      "jordanbaird-ice"
      "meetingbar"
      "notion"
      "obsidian"
      "spotify"
      "visual-studio-code"
      "whatsapp"
      "zoom"
    ];

    # masApps disabled — mas 2.x CLI is incompatible with nix-darwin's brew bundle integration
    # install manually: Monosnap (App Store ID 540348655)
  };

  environment.systemPackages = [ brewHealth ];

  # report broken casks at the end of every switch, and NEVER fail.
  #
  # `|| true` is load-bearing: a non-zero exit in an activation script aborts
  # the rest of activation. this runs via mkAfter (after the home-manager step)
  # so the blast radius is already small, but the --force-cleanup incident
  # showed how quietly a mid-activation abort skips user-level config.
  #
  # reports only — repair downloads large artifacts, which is not something a
  # rebuild should do behind your back. run `brew-health --repair` to act.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/sudo -u ${user.name} ${brewHealth}/bin/brew-health || true
  '';
}

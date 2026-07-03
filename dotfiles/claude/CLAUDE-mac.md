# macos-specific instructions

* when using coreutils commands, prefer g-prefixed gnu versions (e.g., gls, gstat)
* use macos-native tools where appropriate (e.g., pbcopy, pbpaste)
* **strong preference for nix; homebrew is a last resort.** add packages to the nix config and rebuild — nixpkgs `home.packages`/`systemPackages` for cli tools, or the declarative `homebrew.brews`/`homebrew.casks` list for brew-only formulae/casks. never install or remove packages imperatively with brew unless nix genuinely cannot do it. (`brew update` during a nix-darwin rebuild is expected and fine.) **enforced by a PreToolUse Bash hook in settings-mac.json — imperative `brew install`/`reinstall`/`tap`/`upgrade`/`uninstall` (and the `remove`/`rm` aliases) triggers an `ask` gate with this reminder.**

## nix-darwin rebuild

macos machines use nix-darwin, not home-manager. the rebuild command is:

```bash
darwin-rebuild switch --flake <flake-path>#$HM_CONFIG_NAME
```

* for personal mac: `darwin-rebuild switch --flake ~/.config/home-manager#$HM_CONFIG_NAME`
* for machines built from a downstream flake: use that flake's path (see machine-specific instructions)

## system.defaults gotchas

* nix-darwin's structured `system.defaults.{trackpad,mouse,...}` only writes per-app domains (e.g. `com.apple.AppleMultitouchTrackpad`). modern macos often reads the same setting from a different layer — `NSGlobalDomain` or ByHost (`-currentHost`) — so writing the per-app key alone leaves the gesture working without UI feedback, or vice versa. **set both layers** when adding a new pref.
* concrete examples already in this repo:
    * tap-to-click — `system.defaults.trackpad.Clicking = true` (driver) + `NSGlobalDomain."com.apple.mouse.tapBehavior" = 1` (UI/system-wide).
    * 3-finger tap → look up & data detectors — `system.defaults.trackpad.TrackpadThreeFingerTapGesture = 2` (driver) + a postActivation script writing the ByHost key `com.apple.trackpad.threeFingerTapGesture`.
* diagnostic recipe — for any pref where the system settings ui shows the wrong state:
    ```
    defaults read <domain> <key>            # per-app
    defaults read -g <key>                  # NSGlobalDomain
    defaults -currentHost read -g <key>     # NSGlobalDomain ByHost
    ```
    the layer matching what the ui displays is the one driving the feature.

## activation scripts

* `system.activationScripts.postUserActivation` was removed — all activation now runs as `root`. to run as the user (e.g., per-user `defaults -currentHost write`), use `postActivation.text = lib.mkAfter ''…''` and drop privileges with `/usr/bin/sudo -u ${user.name} <command>`. bind `user = config.users.users.${config.system.primaryUser}` at the top of the module.
* nix-darwin doesn't expose `-currentHost` writes declaratively — use this pattern.

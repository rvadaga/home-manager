# macos-specific instructions

* when using coreutils commands, prefer g-prefixed gnu versions (e.g., gls, gstat)
* use macos-native tools where appropriate (e.g., pbcopy, pbpaste)
* **strong preference for nix; homebrew is a last resort.** add packages to the nix config and rebuild — nixpkgs `home.packages`/`systemPackages` for cli tools, or the declarative `homebrew.brews`/`homebrew.casks` list for brew-only formulae/casks. never install or remove packages imperatively with brew unless nix genuinely cannot do it. (`brew update` during a nix-darwin rebuild is expected and fine.) **enforced by a PreToolUse Bash hook in settings-mac.json — imperative `brew install`/`reinstall`/`tap`/`upgrade`/`uninstall` (and the `remove`/`rm` aliases) triggers an `ask` gate with this reminder.**

## home and system activation

macos uses standalone home-manager for known home-only changes and nix-darwin for system changes.

```bash
home-manager switch --flake <flake-path>#$HM_CONFIG_NAME
```

home-manager activation is user-scoped and must not use sudo. the pinned home-manager cli is also present in the embedded nix-darwin home generation, so a later system switch does not remove the command needed for the next home-only change.

for a system change, or a change whose ownership is unclear, build without activation first:

```bash
darwin-rebuild build --flake <flake-path>#$HM_CONFIG_NAME
```

the actual system activation requires rahul to authenticate and run or explicitly authorize the exact command:

```bash
sudo darwin-rebuild switch --flake <flake-path>#$HM_CONFIG_NAME
```

an agent stops before that authenticated command. machines built from a downstream flake use the downstream flake path for both graphs.

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

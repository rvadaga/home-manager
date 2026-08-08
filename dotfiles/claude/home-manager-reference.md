# nix configuration reference

detailed workflows and examples for managing claude code settings with standalone home-manager and nix-darwin.
for the condensed version, see CLAUDE.md.

## updating CLAUDE.md or settings.json in ~/.claude folder

### overview

* CLAUDE.md is managed by nix as a read-only symlink — edit the source files and rebuild
* settings.json uses an **additive merge** model:
    * on every home activation, the nix baseline is deep-merged into the live file
    * objects merge recursively — live values win on scalar conflicts
    * arrays are union-merged (concat + deduplicate) — new nix permissions appear without losing locally-approved ones
    * on first run (or if the file is missing/still a symlink), the file is seeded from the nix baseline
* settings.local.json is **not managed by nix** — claude code owns it entirely
* to export live settings back to nix source files, use the `/sync-claude-settings` skill
* to compare live vs nix source without modifying anything, use the `/diff-claude-settings` skill
* source files live in ~/.config/home-manager/dotfiles/claude/
* settings are split by environment and merged together during home-manager build
* **for CLAUDE.md changes:** edit the source file(s) and run `home-manager switch`
* **for settings changes:** edit files directly in `~/.claude/` (takes effect immediately), then run `/sync-claude-settings` to propagate back to nix source files

## codex config.toml

`codex.settingsPieces` accepts a list of nix attribute sets. the base config reads `dotfiles/codex/settings-base.toml` into the first piece, and downstream configs can append their own pieces with `lib.mkAfter`.

home-manager folds the nix pieces in order, with later pieces winning scalar conflicts. on activation it recursively merges that result into `~/.codex/config.toml`: live scalars and array order win, while missing nix keys and array entries are added.

stable desired plugin enablement and desktop defaults can live in these pieces because the live file still wins conflicts. keep generated app state out: notification paths, marketplace metadata, project trust, generated mcp server entries and environment values, and hook trust hashes.

## file structure

claude settings are organized into environment-specific pieces:

* `settings-base.json` - shared settings across all environments (model, plugins, permissions, mcp servers, etc.)
* `settings-mac.json` - macos-specific settings (mac-only permissions)
* `settings-linux.json` - linux-specific settings (linux-only permissions)
* `settings-nixos.json` - nixos-specific settings (nixos-only permissions)

codex files and downstream pieces are described in [codex config.toml](#codex-configtoml).

CLAUDE.md uses the same pattern:

* `CLAUDE-base.md` - shared instructions
* `CLAUDE-mac.md` - macos-specific instructions
* `CLAUDE-linux.md` - linux-specific instructions
* `CLAUDE-nixos.md` - nixos-specific instructions

## how to update settings

### quick edits (settings.json)

edit `~/.claude/settings.json` directly — changes take effect immediately.

### propagating live settings to nix source files

use the `/sync-claude-settings` skill to export live settings back to the nix source files. it auto-routes permissions to os-specific files by keyword matching:
- linux: `spectacle`, `dbus-send`, `pgrep`, `fc-list`, `xdg`, `kde`, etc.
- nixos: `nixos-rebuild`, `nix-env`, `journalctl`, `systemctl`, `nix profile`, etc.
- mac: `open -a`, `pbcopy`, `pbpaste`, `defaults write`, `osascript`, etc.
- everything else → base

plugins, mcp servers, and all other top-level keys always go to base.

use `/diff-claude-settings` for a read-only comparison without making changes.

### updating nix source files directly

1. **for settings that apply everywhere:** edit `settings-base.json`
2. **for os-specific permissions:** edit the appropriate `settings-{os}.json`
3. **for instructions:** edit the appropriate `CLAUDE-{os}.md` file

## update workflows

### for CLAUDE.md (managed as a symlink)

1. edit the source file in `~/.config/home-manager/dotfiles/claude/`
2. publish a draft pull request and merge it only after approval
3. run `home-manager switch --flake <flake-path>#$HM_CONFIG_NAME`
4. verify changes in `~/.claude/CLAUDE.md`

### for settings (additive merge on rebuild)

1. edit the source file in `~/.config/home-manager/dotfiles/claude/`
2. commit and push
3. rebuild — merges nix baseline into live file (live values win on conflicts, arrays are unioned)

### for syncing locally-approved permissions to nix source

1. run `/sync-claude-settings` to export and route permissions
2. commit and push the updated source files
3. on other machines: pull and rebuild to pick up the changes

the `$HM_CONFIG_NAME` environment variable is set in each machine config and identifies which configuration to use (e.g., "personal-laptop", "nixos-workstation")

## using --override-input for local testing

only needed when making significant changes to `*.nix` files that warrant testing before pushing.

when editing this personal config on a machine with a downstream config:
1. make the edit here in `~/.config/home-manager`
2. classify the evaluated outputs. for a known home-only change, build home-manager. for a known system-only change, build nix-darwin. for a shared input or unclear change, run both commands:
   ```bash
   home-manager build --flake <downstream-flake-path>#$HM_CONFIG_NAME \
     --override-input personal-config path:$HOME/.config/home-manager
   darwin-rebuild build --flake <downstream-flake-path>#$HM_CONFIG_NAME \
     --override-input personal-config path:$HOME/.config/home-manager
   ```
3. once confirmed working, publish the personal config draft and wait for approval
4. update the flake lock in the downstream config:
   ```bash
   # run these as separate commands (not chained with &&)
   # cd to the downstream flake path, then:
   nix flake update personal-config
   ```
5. build without the override to confirm the lock is correct. after merge, a known home-only change uses sudo-free `home-manager switch`. a macos system activation stops for rahul to run or explicitly authorize the authenticated `sudo darwin-rebuild switch` command

## command choice and rollback

choose from evaluated ownership, not a filename allowlist or denylist. obvious home modules and managed dotfiles can be treated as home-only. flake files, lock files, overlays, and shared imports can affect both graphs, so build both when the effect is unclear.

standalone home-manager and nix-darwin keep separate rollback histories. `home-manager generations` and `home-manager rollback` manage standalone home generations. nix-darwin manages system generations. the live home links follow the most recently activated standalone or embedded home generation. `nix-provenance` reports both active layers and whether the home stamp agrees with `current-home`.

**note:** if you rebuild a downstream flake without `--override-input` after making unpushed local changes, it will use the old locked revision.

## examples

**adding a permission via nix source:**
```
# edit shared settings
edit ~/.config/home-manager/dotfiles/claude/settings-base.json
# publish and merge the draft, then activate the home-only change
home-manager switch --flake <flake-path>#$HM_CONFIG_NAME
```

**syncing locally-approved permissions back to nix:**
```
# use the skill — it shows a diff and writes on confirmation
/sync-claude-settings
# then commit and push
```

**updating instructions:**
```
# edit shared instructions
edit ~/.config/home-manager/dotfiles/claude/CLAUDE-base.md
# publish and merge the draft, then activate the home-only change
home-manager switch --flake <flake-path>#$HM_CONFIG_NAME
```

## notes

* other configuration repos may exist separately and are not accessible from this config
* other repos may use this repo as a flake input, so changes here may affect those configurations
* claude settings pieces use json; the codex base settings file uses toml
* nix-owned pieces are merged recursively - later nix values override earlier ones
* pieces merge in declared order: base → os-specific or downstream additions, so later nix pieces override earlier ones

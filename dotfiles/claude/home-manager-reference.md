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
    * values declared in `claude.forcedSettings` replace their live values after the merge, including whole arrays; other live values keep the precedence above
    * the x bridge command and arguments use this override so obsolete launchers cannot survive a rebuild
    * on first run (or if the file is missing/still a symlink), the file is seeded from the nix baseline with those overrides applied
* settings.local.json is **not managed by nix** — claude code owns it entirely
* to export live settings back to nix source files, use the `/sync-claude-settings` skill
* to compare live vs nix source without modifying anything, use the `/diff-claude-settings` skill
* source files live in ~/.config/home-manager/dotfiles/claude/
* settings are split by environment and merged together during home-manager build
* **for CLAUDE.md changes:** edit the source in an isolated worktree and complete `/nix-rebuild`
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

use `/nix-rebuild` for source changes and `/ship-config` to finish work already in a worktree. both follow [config task authorization](skills/nix-rebuild/SKILL.md#config-task-authorization). this reference leaves authorization there to avoid a second approval requirement.

### for CLAUDE.md (managed as a symlink)

edit the appropriate source in the isolated worktree, then complete `/nix-rebuild`. verify the merged instructions in `~/.claude/CLAUDE.md` after activation.

### for settings (merged on rebuild)

edit the source in the isolated worktree, then complete `/nix-rebuild`. verify the changed setting using the precedence described in the overview above.

### for syncing locally-approved permissions to nix source

use `/sync-claude-settings` to export and route permissions in the isolated worktree, then complete `/nix-rebuild`. other machines pick up the merged source on their next authorized rebuild.

the `$HM_CONFIG_NAME` environment variable is set in each machine config and identifies which configuration to use (e.g., "personal-laptop", "nixos-workstation")

## using --override-input for local testing

only needed when making significant changes to `*.nix` files that warrant testing before pushing.

when editing this personal config on a machine with a downstream config:
1. make the edit in an isolated worktree of this personal config
2. classify the evaluated outputs. for a known home-only change, build home-manager. for a known system-only change, build nix-darwin. for a shared input or unclear change, run both commands:
   ```bash
   home-manager build --flake <downstream-flake-path>#$HM_CONFIG_NAME \
     --override-input personal-config path:<worktree>
   darwin-rebuild build --flake <downstream-flake-path>#$HM_CONFIG_NAME \
     --override-input personal-config path:<worktree>
   ```
3. publish the personal config draft, share the validation results, and merge under the linked config task authorization rule
4. update the flake lock in an isolated downstream worktree and complete its `/nix-rebuild` workflow:
   ```bash
   # run these as separate commands (not chained with &&)
   # cd to the downstream flake path, then:
   nix flake update personal-config
   ```
5. before the downstream merge, build without the override to confirm the lock is correct. after both prs merge, activate and verify through `/nix-rebuild` using the downstream flake

## command choice and rollback

choose from evaluated ownership, not a filename allowlist or denylist. obvious home modules and managed dotfiles can be treated as home-only. flake files, lock files, overlays, and shared imports can affect both graphs, so build both when the effect is unclear.

standalone home-manager and nix-darwin keep separate rollback histories. `home-manager generations` and `home-manager rollback` manage standalone home generations. nix-darwin manages system generations. the live home links follow the most recently activated standalone or embedded home generation. `nix-provenance` reports both active layers and whether the home stamp agrees with `current-home`.

**note:** if you rebuild a downstream flake without `--override-input` after making unpushed local changes, it will use the old locked revision.

## examples

**adding a permission via nix source:**
```
# use nix-rebuild to edit shared settings in its worktree and complete the workflow
/nix-rebuild
```

**syncing locally-approved permissions back to nix:**
```
# export the requested settings in the nix-rebuild worktree
/sync-claude-settings
# complete publication, validation, merge, and activation through nix-rebuild
/nix-rebuild
```

**updating instructions:**
```
# use nix-rebuild to edit shared instructions in its worktree and complete the workflow
/nix-rebuild
```

## notes

* other configuration repos may exist separately and are not accessible from this config
* other repos may use this repo as a flake input, so changes here may affect those configurations
* claude settings pieces use json; the codex base settings file uses toml
* nix-owned pieces are merged recursively - later nix values override earlier ones
* pieces merge in declared order: base → os-specific or downstream additions, so later nix pieces override earlier ones

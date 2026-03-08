# base instructions

* when writing ANY new content, always use lower case.
    * when editing existing docs, follow the casing and styling conventions already used in that doc. if the doc is internally inconsistent, match the nearest surrounding section
    * when creating new docs, use the default lower case style
    * when editing, preserve case for code, variable names, identifiers, abbreviations and actual code
    * product names are lower case too
* when working on pull requests:
    * unless specifically asked not to, create a DRAFT pr
    * don't add ai generated prompt
    * always use pull request templates available in the repository
    * if it doesn't exist in the repo, please use the one in ~/development/.github/ folder
    * always read the pr description from github before updating it (user may have made changes via github ui)
* when creating a branch
    * prefix the name with rahul/
* when making any home-manager config changes:
    * run home-manager switch (or nixos-rebuild on nixos) to apply changes
    * skip `exec $SHELL` - claude code's shell snapshot is captured at conversation start and won't update mid-conversation; new shell changes take effect in the next conversation
    * after confirming changes look good and expected, always follow up by committing and pushing to remote
* always prefer fetching just the branch that was needed, if needed to fetch everything, get the users permission
* use oh-my-zsh git plugin aliases for all git commands. always put the equivalent full git command in the bash tool's `description` field (not as an inline `#` comment in the command itself, since that breaks permission matching). example: run `gcmsg "fix bug"` with description "git commit --message". the full alias reference is at `~/.config/home-manager/dotfiles/claude/omz-git-aliases.md`
* never chain commands with `&&` or `;` in bash tool calls — compound commands break permission matching even when each individual command is allowed. if you need to run git commands in a different repo, prefer `git -C <path>` instead of `cd <path> && git ...`
# home-manager configuration

## multi-repo structure

this personal/base home-manager config (`~/.config/home-manager`) can be imported as a flake input by other configs (e.g., work-specific configs). on machines with layered configs:

* the downstream config imports this repo as `inputs.personal-config`
* CLAUDE.md files from both repos get combined
* check `$HM_CONFIG_NAME` to determine which flake to rebuild against
* if rebuilding a downstream config, use that config's flake path (not this one)

**critical: downstream configs import this repo as a git flake input, so `flake.lock` pins to a specific git revision. simply running `home-manager switch` with the downstream flake will NOT pick up local changes here unless you explicitly override the input.**

when editing this personal config on a machine with a downstream config:
1. make the edit here in `~/.config/home-manager`
2. to test/apply locally, use `--override-input` to point the downstream flake at the local path:
   ```bash
   home-manager switch --flake <downstream-flake-path>#$HM_CONFIG_NAME \
     --override-input personal-config path:$HOME/.config/home-manager
   ```
3. once confirmed working, commit and push the personal config changes
4. update the flake lock in the downstream config:
   ```bash
   cd <downstream-flake-path> && nix flake update personal-config
   ```
5. rebuild without the override to confirm the lock is correct

**never rebuild a downstream flake without `--override-input` after editing this repo - it will silently use the old locked revision.**

## updating CLAUDE.md or settings.json in ~/.claude folder

### overview

* CLAUDE.md is managed by home-manager as a read-only symlink — edit the source files and rebuild
* settings.json uses an **additive merge** model:
    * on every `home-manager switch` / `nixos-rebuild switch`, the nix baseline is deep-merged into the live file
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

## file structure

settings are organized into environment-specific pieces:

* `settings-base.json` - shared settings across all environments (model, plugins, permissions, mcp servers, etc.)
* `settings-mac.json` - macos-specific settings (mac-only permissions)
* `settings-linux.json` - linux-specific settings (linux-only permissions)
* `settings-nixos.json` - nixos-specific settings (nixos-only permissions)

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

### update workflow

**for CLAUDE.md (managed as a symlink):**
1. edit the source file in `~/.config/home-manager/dotfiles/claude/`
2. run `home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME`
3. verify changes in `~/.claude/CLAUDE.md`

**for settings (additive merge on rebuild):**
1. edit the source file in `~/.config/home-manager/dotfiles/claude/`
2. run `home-manager switch` — merges nix baseline into live file (live values win on conflicts, arrays are unioned)

**for syncing locally-approved permissions to nix source:**
1. run `/sync-claude-settings` to export and route permissions
2. commit and push the updated source files
3. on other machines: pull and rebuild to pick up the changes

the `$HM_CONFIG_NAME` environment variable is set in each machine config and identifies which configuration to use (e.g., "personal-laptop", "nixos-workstation")

### examples

**adding a permission via nix source:**
```
# edit shared settings
edit ~/.config/home-manager/dotfiles/claude/settings-base.json
# rebuild — merges into live file without losing existing permissions
home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME
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
# rebuild
home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME
```

## notes

* other configuration repos may exist separately and are not accessible from this config
* other repos may use this repo as a flake input, so changes here may affect those configurations
* settings files use json format - ensure valid json when editing
* settings are merged using recursive update - later values override earlier ones
* merge order: base → os-specific (so os-specific settings override base)

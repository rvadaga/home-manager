# base instructions

* when writing ANY new content, always use lower case.
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
    * run home-manager switch and always reload the shell by running `exec $SHELL` for changes to completely take effect
    * after confirming changes look good and expected, always follow up by committing and pushing to remote
* always prefer fetching just the branch that was needed, if needed to fetch everything, get the users permission

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

## updating CLAUDE.md, settings.json or settings.local.json in ~/.claude folder

### overview

* files in ~/.claude are managed by home-manager and are read-only
* source files live in ~/.config/home-manager/dotfiles/claude/
* settings are split by environment and merged together during home-manager build
* to update settings, edit the appropriate source file(s) and run `home-manager switch`

## file structure

settings are organized into environment-specific pieces:

* `settings-base.json` - shared settings across all environments
* `settings-mac.json` - macos-specific settings
* `settings-linux.json` - linux-specific settings
* `settings-nixos.json` - nixos-specific settings
* `settings.local-base.json` - shared local settings (permissions, etc)
* `settings.local-mac.json` - macos-specific local settings
* `settings.local-linux.json` - linux-specific local settings
* `settings.local-nixos.json` - nixos-specific local settings

CLAUDE.md uses the same pattern:

* `CLAUDE-base.md` - shared instructions
* `CLAUDE-mac.md` - macos-specific instructions
* `CLAUDE-linux.md` - linux-specific instructions
* `CLAUDE-nixos.md` - nixos-specific instructions

## how to update settings programmatically

### determine which file to edit

1. **for settings that apply everywhere:** edit `settings-base.json` or `settings.local-base.json`
2. **for os-specific settings:** edit the appropriate `settings-{os}.json` or `settings.local-{os}.json`
3. **for instructions:** edit the appropriate `CLAUDE-{os}.md` file

current system is **macos**, so you'll typically edit:
- `~/.config/home-manager/dotfiles/claude/settings-base.json`
- `~/.config/home-manager/dotfiles/claude/settings-mac.json`
- `~/.config/home-manager/dotfiles/claude/settings.local-base.json` (for permissions)
- `~/.config/home-manager/dotfiles/claude/CLAUDE-base.md` (for shared instructions)
- `~/.config/home-manager/dotfiles/claude/CLAUDE-mac.md` (for macos instructions)

### update workflow

1. read the appropriate source file from `~/.config/home-manager/dotfiles/claude/`
2. edit the file with your changes
3. run `home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME` to rebuild and apply changes
4. verify the changes took effect by reading `~/.claude/settings.json` or `~/.claude/CLAUDE.md`

the `$HM_CONFIG_NAME` environment variable is set in each machine config and identifies which configuration to use (e.g., "personal-laptop", "nixos-workstation")

### examples

**adding a new global setting:**
```
# edit shared settings
edit ~/.config/home-manager/dotfiles/claude/settings-base.json
# rebuild
home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME
```

**adding macos-specific permission:**
```
# edit mac-specific local settings
edit ~/.config/home-manager/dotfiles/claude/settings.local-mac.json
# rebuild
home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME
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

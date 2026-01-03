# base instructions

* when writing ANY new content, always use lower case.
    * when editing, preserve case for code, variable names, identifiers, abbreviations and actual code
    * product names are lower case too
* when working on pull requests:
    * unless specifically asked not to, create a DRAFT pr
    * don't add ai generated prompt
    * always use pull request templates available in the repository
    * if it doesn't exist in the repo, please use the one in ~/development/.github/ folder
* when creating a branch
    * prefix the name with rahul/
* when making any home-manager config changes, always test that they work.
* running home-manager switch command is ok, but NEVER push to remote without getting the user's permission.

# updating CLAUDE.md, settings.json or settings.local.json in ~/.claude folder

## overview

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

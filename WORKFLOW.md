# home-manager workflow

this is the personal config repository that contains shared modules used by multiple configurations.

## repository structure

- `os-configs/base.nix` - base profile with core packages and settings
- `os-configs/mac.nix` - macos-specific configuration
- `os-configs/linux.nix` - linux-specific configuration
- `os-configs/nixos.nix` - nixos-specific configuration
- `programs/` - individual feature modules (neovim, zsh, fzf, etc.)
- `dotfiles/` - managed dotfiles (claude settings split by environment)

## exported modules

this flake exports modules that can be imported by other flakes:

```nix
homeManagerModules = {
  base = ./os-configs/base.nix;
  mac = ./os-configs/mac.nix;
  linux = ./os-configs/linux.nix;
  nixos = ./os-configs/nixos.nix;
  nix-index = { ... };  # comma + nix-index with pre-built database
};
```

## multiple package channels

the flake provides platform-aware nixpkgs channels:

- stable channels auto-select based on platform (darwin-stable or nixos-stable)
- unstable channels auto-select based on platform (darwin-unstable or nixos-unstable)
- staging channels are unified across platforms

access via overlays:
```nix
pkgs.foo           # stable
pkgs.unstable.bar  # unstable
pkgs.staging.baz   # staging
pkgs.staging-next.qux  # staging-next
```

## HM_CONFIG_NAME environment variable

each machine config sets `HM_CONFIG_NAME` to identify itself:

```nix
home.sessionVariables = {
  HM_CONFIG_NAME = "personal-laptop";
};
```

this allows scripts to use `home-manager switch --flake ".#$HM_CONFIG_NAME"` without hardcoding config names.

## workflow for updating shared config

when you make changes to shared modules (base.nix, programs/*, etc.):

1. make changes in this repo
2. commit and push to main
3. other flakes that import this config can update their lock file:
   ```bash
   nix flake update personal-config
   home-manager switch --flake ".#$HM_CONFIG_NAME"
   ```

## claude settings infrastructure

claude settings are managed via split configuration files in `dotfiles/claude/`:

- `settings-base.json` - shared settings (model, plugins, permissions, mcp servers, etc.)
- `settings-{os}.json` - os-specific settings (os-only permissions)
- `CLAUDE-base.md` - shared instructions
- `CLAUDE-{os}.md` - os-specific instructions

files are merged during home-manager build (base → os-specific).

**CLAUDE.md** is managed as a read-only symlink — edit source files and rebuild.

**settings.json** uses an additive merge model — nix manages the baseline, live file wins on conflicts.

**settings.local.json** is not managed by nix — claude code owns it entirely.

### bidirectional settings sync

#### direction 1: import (nix → live) — automatic on every rebuild

on `home-manager switch` / `nixos-rebuild switch`, the activation script (`programs/claude.nix`):
- reads the nix-managed baseline and the existing live file
- deep-merges objects recursively (live values win on scalar conflicts)
- union-merges arrays (concat + deduplicate) — new nix permissions appear without losing locally-approved ones
- on first run (or if file is missing/symlink), seeds from baseline

this means adding a permission to `settings-base.json` and rebuilding will add it to the live file on all machines without overwriting anything.

#### direction 2: export (live → nix source) — on-demand via skills

use `/sync-claude-settings` to export live settings back to the nix source files:
- reads `~/.claude/settings.json`
- classifies permissions by os keyword and routes to the correct file
- routes all other keys (plugins, mcp servers, model, etc.) to base
- shows a diff and writes on user confirmation

use `/diff-claude-settings` for a read-only comparison without modifying anything.

### typical workflow

after approving new permissions locally in claude code:

```
/sync-claude-settings                  # export live → nix source (shows diff, writes on confirm)
# then commit and push
```

on another machine:

```bash
git pull
# rebuild picks up new permissions via additive merge
sudo nixos-rebuild switch --flake ...    # or home-manager switch
```

### updating CLAUDE.md

1. edit the appropriate source file in `dotfiles/claude/`
2. run `home-manager switch --flake ".#$HM_CONFIG_NAME"`
3. verify changes in `~/.claude/CLAUDE.md`

### editing settings directly

edit `~/.claude/settings.json` — changes take effect immediately. run `/sync-claude-settings` to propagate back to nix source files.

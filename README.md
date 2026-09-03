# home-manager configuration

personal nix home-manager and nix-darwin configuration for managing development environments across machines.

## repository organization

* `flake.nix`: entry point defining available configurations and exported modules
* `os-configs/`: reusable configuration building blocks
  * `base.nix`: common packages and settings for all systems
  * `mac.nix`: macos-specific configuration (gpg-agent, ssh, coreutils)
  * `linux.nix`: linux-specific configuration
  * `nixos.nix`: nixos-specific configuration
* `darwin/`: nix-darwin system-level modules (macos only)
  * `default.nix`: umbrella module (stateVersion, primaryUser, touch ID sudo, launchd agents)
  * `nix.nix`: system-level nix settings
  * `homebrew.nix`: declarative homebrew casks
  * `system-defaults.nix`: macos system preferences (dock, finder, trackpad, keyboard, app settings for itsycal, meetingbar, ice)
* `machines/`: per-machine configurations
  * `personal-laptop.nix`: macos standalone home-manager configuration
  * `mac-workstation.nix`: macos nix-darwin + home-manager configuration
  * `nixos-workstation.nix`: nixos configuration
* `programs/`: program-specific configurations (zsh, kitty, fzf, claude)
* `scripts/`: setup and helper scripts
  * `functions.sh`: shared helpers (machine config loading, 1password, github uploads, state tracking)
  * `setup-ssh.sh`: generate SSH key, upload to github, store in 1password
  * `setup-gpg.sh`: generate GPG key, upload to github, store in 1password
  * `setup-licenses.sh`: fetch app license keys from 1password
  * `backup-app-configs.sh`: daily backup of btt, bettermouse, and control center configs to google drive
* `shared/`: configuration shared between nix-darwin and standalone home-manager
  * `nix-settings.nix`: nix daemon settings (experimental features, buffer size)
* `dotfiles/`: managed dotfiles (claude settings split by os, etc.)
* `machine.json`: per-machine identity (machine name, user name, email) — gitignored, created locally during bootstrap
* `bootstrap.sh`: full macos bootstrap from a fresh machine

## macos bootstrap (fresh machine)

prerequisites: internet connection, signed into apple account in system settings.

on a fresh mac (no git yet), run this single command to kick off the full bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/rvadaga/home-manager/main/bootstrap.sh | bash
```

the bootstrap script will:
1. install xcode CLT, nix, and homebrew
2. authenticate the github CLI (opens browser)
3. clone this repo to `~/.config/home-manager`
4. prompt you to create `machine.json` with your identity
5. authenticate for `sudo darwin-rebuild switch` (installs all casks, applies system defaults)
6. prompt you to sign into 1password, then run SSH/GPG/license setup scripts
7. print remaining manual steps (app logins, permissions, config restore)

`machine.json` format (created during bootstrap):

```json
{
  "machine": "my macbook",
  "name": "Your Name",
  "email": "you@example.com"
}
```

after bootstrap, the only manual step is updating `machines/mac-workstation.nix` with the GPG key ID printed by the script, then rebuilding:

```bash
sudo darwin-rebuild switch --flake ~/.config/home-manager#mac-workstation
```

the bootstrap tracks completed steps in `.state/` — re-running it is safe and skips already-completed steps.

## installation (standalone home-manager)

1. install nix: https://nixos.org/download/

2. clone this repository:
```bash
git clone https://github.com/rvadaga/home-manager ~/.config/home-manager
cd ~/.config/home-manager
```

3. activate the configuration:
```bash
nix run home-manager/release-25.11 -- switch --flake ".#personal-laptop"
```

## usage

### apply configuration

for a known home-only change on any home-manager target:
```bash
home-manager switch --flake ".#$HM_CONFIG_NAME"
```

for a nix-darwin system change:
```bash
sudo darwin-rebuild switch --flake ".#mac-workstation"
```

build a system change without activation before asking the user to authenticate:
```bash
darwin-rebuild build --flake ".#mac-workstation"
```

the `HM_CONFIG_NAME` environment variable is set by your machine config and identifies which configuration to use.

### update dependencies
```bash
nix flake update
```

### add a new host
copy an existing machine config from `machines/` and customize the imports and settings.

## multiple package channels

the flake provides platform-aware nixpkgs channels via overlays:

- `pkgs.*` - stable (nixpkgs-25.11-darwin or nixos-25.11)
- `pkgs.unstable.*` - unstable (nixpkgs-unstable or nixos-unstable)
- `pkgs.staging.*` - staging channel
- `pkgs.staging-next.*` - staging-next channel

use unstable/staging for packages that need newer versions:
```nix
home.packages = [
  pkgs.foo           # stable
  pkgs.unstable.bar  # unstable
];
```

## exported modules

this flake exports reusable modules that other configurations can import:

### home-manager modules
* `homeManagerModules.base` - common packages and settings
* `homeManagerModules.mac` - macos-specific configuration
* `homeManagerModules.linux` - linux-specific configuration
* `homeManagerModules.nixos` - nixos-specific configuration
* `homeManagerModules.nix-index` - comma and nix-index with pre-built database

### darwin modules
* `darwinModules.base` - system-level nix settings
* `darwinModules.desktop` - macos system preferences (dock, finder, keyboard, trackpad, app settings)
* `darwinModules.homebrew` - declarative homebrew casks

all darwin module values use `lib.mkDefault` so downstream configs can override without `lib.mkForce`.

to bootstrap nix-darwin for the first time on a downstream config:
```bash
nix run nix-darwin -- switch --flake <path>#<config-name>
```

subsequent system activations use authenticated `sudo darwin-rebuild switch`. home-only activations use sudo-free `home-manager switch`.

## homebrew management

nix-darwin manages homebrew declaratively — casks are declared in `darwin/homebrew.nix`. homebrew is intentionally kept off `$PATH` to prevent it from interfering with the nix-managed dev environment. nix-darwin calls brew directly via absolute path during activation.

`cleanup = "zap"` ensures the mac converges to exactly what's declared — any unlisted cask is removed on rebuild.

note: `masApps` (mac app store apps) is currently disabled due to a compatibility issue between `mas` 2.x and `brew bundle`. app store apps must be installed manually for now.

## comma and nix-index

[comma](https://github.com/nix-community/comma) (`,`) lets you run any program from nixpkgs without installing it, and `nix-locate` (provided by nix-index) lets you search for which package provides a given file:

```bash
, jshell                    # runs jshell via nix shell
, cowsay                    # runs cowsay via nix shell
nix-locate cowsay           # find which packages provide cowsay
```

the database is provided automatically by the [nix-index-database](https://github.com/nix-community/nix-index-database) flake input — no manual setup or periodic rebuilds needed. the database is updated weekly upstream; run `nix flake update nix-index-database` to pull the latest.

the `homeManagerModules.nix-index` export bundles the nix-index-database home-manager module with the configuration, so downstream configs just need one import line:

```nix
imports = [
  inputs.personal-config.homeManagerModules.nix-index
];
```

this enables:
- `comma` wrapped with the pre-built database
- `nix-locate` wrapped with the pre-built database
- command-not-found shell integration (suggests packages when a missing command is typed)

## claude code settings sync

claude code's `settings.json` is a mutable file that claude code modifies at runtime (permissions, plugins, mcp servers). this config uses bidirectional sync to keep it in line across machines. `settings.local.json` is not managed by nix.

### import (nix → live) — automatic on every rebuild

on `home-manager switch` / `darwin-rebuild switch`, the activation script additively merges nix-managed baseline settings into the live file. objects merge recursively (live wins on conflicts), arrays are union-merged (new entries from nix appear without losing locally-approved ones).

settings source files in `dotfiles/claude/` are split by os:
- `settings-base.json` - shared across all environments (model, plugins, permissions, mcp servers, etc.)
- `settings-{mac,linux,nixos}.json` - os-specific (os-only permissions)

### export (live → nix source) — on-demand via skills

use `/sync-claude-settings` in claude code to export live settings back to the nix source files. it reads `~/.claude/settings.json`, classifies permissions by os keyword, routes them to the correct file, shows a diff, and writes on confirmation.

use `/diff-claude-settings` for a read-only comparison without modifying anything.

## app config backups

a daily launchd agent (`backup-app-configs`) backs up app configs that can't be managed declaratively to google drive (`gdrive documents/software/`). it only overwrites when the local copy is newer, and skips gracefully if google drive isn't mounted.

### what's backed up

| app | location on gdrive | contents |
|-----|-------------------|----------|
| bettertouchtool | `software/bettertouchtool/` | sqlite databases, license, presets, preferences plist |
| bettermouse | `software/bettermouse/` | config files (`.padl`, `.spadl`), preferences plist |
| control center | `software/macos-system/` | `com.apple.controlcenter.plist` (menubar items, order, control center layout) |

### restoring from backup

**bettertouchtool:**
```bash
GDRIVE="$HOME/Library/CloudStorage/GoogleDrive-rahul.vadaga@gmail.com/My Drive/gdrive documents/software"
# quit btt first, then:
rsync -a "$GDRIVE/bettertouchtool/" "$HOME/Library/Application Support/BetterTouchTool/"
cp "$GDRIVE/bettertouchtool/com.hegenberg.BetterTouchTool.plist" "$HOME/Library/Preferences/"
```

**bettermouse:**
```bash
# quit bettermouse first, then:
rsync -a "$GDRIVE/bettermouse/" "$HOME/Library/Application Support/BetterMouse/"
cp "$GDRIVE/bettermouse/com.naotanhaocan.BetterMouse.plist" "$HOME/Library/Preferences/"
```

**control center (menubar items + order):**
```bash
# close system settings first, then:
cp "$GDRIVE/macos-system/com.apple.controlcenter.plist" "$HOME/Library/Preferences/"
killall ControlCenter  # restarts automatically
```

### what's managed declaratively in nix

app settings for itsycal, meetingbar, and ice are managed via `system.defaults.CustomUserPreferences` in `darwin/system-defaults.nix` — these are applied automatically on `darwin-rebuild switch`.

## architecture notes

### dual-context modules (`osConfig ? null`)

`os-configs/base.nix` uses the `osConfig ? null` pattern so the same module works in both standalone home-manager and nix-darwin contexts. when running under nix-darwin (`osConfig` is set):
- `programs.home-manager.enable` keeps the pinned cli in the embedded user profile
- the `nix` settings block is skipped (nix-darwin owns these at system level via `darwin/nix.nix`)

nix settings are shared via `shared/nix-settings.nix` to avoid drift between the two contexts.

### ssh and gpg on macos

ssh config and gpg-agent are set up in `os-configs/mac.nix` since `services.gpg-agent` and `programs.ssh` have systemd dependencies that don't exist on macos:
- `gpg-agent.conf` is written directly via `home.file` with `pinentry-mac`
- `programs.ssh.enableDefaultConfig = false` suppresses the home-manager deprecation warning about `~/.ssh/config` management

## available configurations

| name | system | type | description |
|------|--------|------|-------------|
| `mac-workstation` | aarch64-darwin | nix-darwin + home-manager | full macos bootstrap with system settings, homebrew, and user config |
| `personal-laptop` | aarch64-darwin | standalone home-manager | user-level config only (no system settings) |
| `nixos-workstation` | x86_64-linux | standalone home-manager | nixos workstation |

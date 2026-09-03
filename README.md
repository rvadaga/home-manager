# home-manager configuration

personal nix home-manager and nix-darwin configuration for managing development environments across machines.

## repository organization

* `flake.nix`: entry point defining available configurations and exported modules
* `os-configs/`: reusable configuration building blocks
  * `base.nix`: common packages and settings for all systems
  * `llm-instructions.nix`: shared composition of os instruction and settings layers
  * `mac.nix`: macos-specific configuration (gpg-agent, ssh, coreutils)
  * `linux.nix`: linux-specific configuration
  * `nixos.nix`: nixos-specific configuration
* `darwin/`: nix-darwin system-level modules (macos only)
  * `common.nix`: umbrella module for the complete personal macos system
  * `app-registry.nix`: app data shared by installation, dock, setup, preferences, and backups
  * `apps.nix`: typed app module that validates the registry and generates app configuration
  * `nix.nix`: system-level nix settings
  * `homebrew.nix`: homebrew activation policy
  * `system-defaults.nix`: app-independent macos preferences
* `machines/`: per-machine configurations
  * `hosts.nix`: system, user, home directory, module paths, and machine flags
  * `host.nix`: shared home-manager settings derived from the selected host
  * machine modules: os imports and exceptional overrides only
* `programs/`: program-specific configurations (zsh, kitty, fzf, claude)
* `scripts/`: setup and helper scripts
  * `functions.sh`: shared helpers (machine config loading, 1password, github uploads, state tracking)
  * `setup-ssh.sh`: generate SSH key, upload to github, store in 1password
  * `setup-gpg.sh`: generate GPG key, upload to github, store in 1password
* `shared/`: configuration shared between nix-darwin and standalone home-manager
  * `deep-merge.nix`: recursive settings merge used by claude and codex
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
6. prompt you to sign into 1password, then run ssh, gpg, and generated app-license setup
7. read the generated app manifest and print only the remaining app steps

`machine.json` format (created during bootstrap):

```json
{
  "machine": "my macbook",
  "name": "Your Name",
  "email": "you@example.com"
}
```

after bootstrap, the only manual step is updating the selected entry in `machines/hosts.nix` with the gpg key id printed by the script, then rebuilding:

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

add one entry to `machines/hosts.nix`, select its home-manager and optional nix-darwin modules, then keep exceptional overrides in the selected machine module. the configuration name passed by the flake becomes both `HM_CONFIG_NAME` and the app profile, so those values cannot drift apart.

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
* `darwinModules.common` - complete personal macos system module
* `darwinModules.base` - compatibility name for system-level nix settings
* `darwinModules.apps` - app registry, homebrew casks, dock, preferences, privacy policy, setup, licenses, aliases, and backups
* `darwinModules.desktop` - app-independent macos preferences
* `darwinModules.homebrew` - compatibility name for `darwinModules.apps`
* `darwinModules.provenance` - active flake source stamp

desktop defaults and registry-generated app outputs use `lib.mkDefault`. downstream configs can add records through `personal.apps.additional` and disable inherited records through `personal.apps.disabled` without replacing generated lists.

to bootstrap nix-darwin for the first time on a downstream config:
```bash
nix run nix-darwin -- switch --flake <path>#<config-name>
```

subsequent system activations use authenticated `sudo darwin-rebuild switch`. home-only activations use sudo-free `home-manager switch`.

## homebrew management

nix-darwin manages homebrew declaratively. enabled casks are generated from `darwin/app-registry.nix`; `darwin/homebrew.nix` owns only activation behavior. homebrew is intentionally kept off `$PATH` so it does not interfere with the nix-managed development environment.

cleanup is temporarily set to `"none"` because the current nix-darwin integration emits a homebrew flag that homebrew 5.x removed for the destructive cleanup modes. declared casks are still installed, but undeclared casks are not removed until that integration is fixed.

note: `masApps` (mac app store apps) is currently disabled due to a compatibility issue between `mas` 2.x and `brew bundle`. app store apps must be installed manually for now.

## app registry

`darwin/app-registry.nix` is the only place that names an app-specific cask, dock path, preference domain, privacy identity or permission, bootstrap step, login item step, license target, shell alias, or backup source. `darwin/apps.nix` validates that data and derives the nix-darwin values, privacy artifacts, setup commands, and bootstrap manifest.

add an app id to `personal.apps.disabled`, set its registry `enable` field to `false`, or remove the source record to remove every generated reference. profile-specific apps use the `profiles` field instead of machine-local cask, dock, or privacy overrides. the flake check disables apps that exercise installation, dock, preferences, privacy, login items, licenses, aliases, and backups, requires unrelated apps to remain, then checks the evaluated configuration and generated files for orphaned references.

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

a daily launchd agent (`backup-app-configs`) backs up app configs that cannot be managed declaratively to google drive (`gdrive documents/software/`). `darwin/apps.nix` generates the command from backup fields on enabled app records, so disabling an app also removes its backup source. it only overwrites when the local copy is newer and skips gracefully if google drive is not mounted.

inspect the generated backup and restore data instead of maintaining a second app list in this file:

```bash
nix eval --json '.#darwinConfigurations.<config-name>.config.personal.apps.manifest.backups'
nix eval --json '.#darwinConfigurations.<config-name>.config.personal.apps.manifest.restore'
```

app preferences are stored beside their app records and rendered to `system.defaults.CustomUserPreferences` by `darwin/apps.nix`. non-app files belong in `personal.apps.backups.extraFiles` on the machine that owns them.

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

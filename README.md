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
  * `default.nix`: umbrella module (stateVersion, primaryUser, touch ID sudo)
  * `nix.nix`: system-level nix settings
  * `homebrew.nix`: declarative homebrew casks and app store apps
  * `system-defaults.nix`: macos system preferences (dock, finder, trackpad, keyboard)
* `machines/`: per-machine configurations
  * `personal-laptop.nix`: macos standalone home-manager configuration
  * `mac-workstation.nix`: macos nix-darwin + home-manager configuration
  * `nixos-workstation.nix`: nixos configuration
* `programs/`: program-specific configurations (zsh, kitty, fzf, claude)
* `scripts/`: setup and helper scripts
  * `setup-ssh.sh`: generate SSH key, upload to github, store in 1password
  * `setup-gpg.sh`: generate GPG key, upload to github, store in 1password
  * `setup-licenses.sh`: fetch app license keys from 1password
* `dotfiles/`: managed dotfiles (claude settings split by os, etc.)
* `bootstrap.sh`: full macos bootstrap from a fresh machine

## macos bootstrap (fresh machine)

run the bootstrap script on a new mac — it installs xcode CLT, nix, homebrew, clones this repo, and runs the first build:

```bash
curl -fsSL https://raw.githubusercontent.com/rvadaga/home-manager/main/bootstrap.sh | bash
```

or clone manually and run:

```bash
git clone https://github.com/rvadaga/home-manager ~/.config/home-manager
~/.config/home-manager/bootstrap.sh
```

after bootstrap, run the one-time setup scripts:

```bash
# sign into 1password app first, then:
./scripts/setup-ssh.sh      # generate SSH key, upload to github
./scripts/setup-gpg.sh      # generate GPG key, upload to github
./scripts/setup-licenses.sh # apply app license keys
```

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

### rebuild configuration

for nix-darwin (mac-workstation):
```bash
darwin-rebuild switch --flake ".#mac-workstation"
```

for standalone home-manager:
```bash
home-manager switch --flake ".#$HM_CONFIG_NAME"
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
* `darwinModules.desktop` - macos system preferences (dock, finder, keyboard, trackpad)
* `darwinModules.homebrew` - declarative homebrew casks and app store apps

## homebrew management

nix-darwin manages homebrew declaratively — casks and app store apps are declared in `darwin/homebrew.nix`. homebrew is intentionally kept off `$PATH` to prevent it from interfering with the nix-managed dev environment. nix-darwin calls brew directly via absolute path during activation.

`cleanup = "zap"` ensures the mac converges to exactly what's declared — any unlisted cask or app store app is removed on rebuild.

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

## available configurations

| name | system | type | description |
|------|--------|------|-------------|
| `mac-workstation` | aarch64-darwin | nix-darwin + home-manager | full macos bootstrap with system settings, homebrew, and user config |
| `personal-laptop` | aarch64-darwin | standalone home-manager | user-level config only (no system settings) |
| `nixos-workstation` | x86_64-linux | standalone home-manager | nixos workstation |

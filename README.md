# home-manager configuration

personal nix home-manager configuration for managing development environments across machines.

## repository organization

* `flake.nix`: entry point defining available configurations and exported modules
* `os-configs/`: reusable configuration building blocks
  * `base.nix`: common packages and settings for all systems
  * `mac.nix`: macos-specific configuration
  * `linux.nix`: linux-specific configuration
  * `nixos.nix`: nixos-specific configuration
* `machines/`: per-machine configurations
  * `personal-laptop.nix`: macos configuration
  * `nixos-workstation.nix`: nixos configuration
* `programs/`: program-specific configurations (zsh, kitty, fzf)
* `scripts/`: bash scripts and helper functions
* `dotfiles/`: managed dotfiles (claude settings, etc.)

## installation

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

* `homeManagerModules.base` - common packages and settings
* `homeManagerModules.mac` - macos-specific configuration
* `homeManagerModules.linux` - linux-specific configuration
* `homeManagerModules.nixos` - nixos-specific configuration

## comma and nix-index

[comma](https://github.com/nix-community/comma) (`,`) and [nix-index](https://github.com/nix-community/nix-index) are included in the base configuration. comma lets you run any program from nixpkgs without installing it, and `nix-locate` (provided by nix-index) lets you search for which package provides a given file:

```bash
, jshell                    # runs jshell via nix shell
, cowsay                    # runs cowsay via nix shell
nix-locate -w bin/jshell    # find which packages provide jshell
```

comma uses [nix-index](https://github.com/nix-community/nix-index) to look up which package provides a given binary. nixpkgs doesn't have a built-in reverse mapping from binary name to package attribute, so nix-index builds a precomputed index of every file path across all packages. without this database, comma has no way to resolve e.g. `jshell` → `openjdk` without evaluating all 80,000+ packages.

the nix-index database must be built or downloaded before comma will work.

### setup (prebuilt database — recommended)

download the prebuilt database from [nix-index-database](https://github.com/Mic92/nix-index-database):

```bash
mkdir -p ~/.cache/nix-index

# for apple silicon macs (aarch64-darwin)
curl -L -o ~/.cache/nix-index/files \
  https://github.com/Mic92/nix-index-database/releases/latest/download/index-aarch64-darwin

# for intel macs (x86_64-darwin)
curl -L -o ~/.cache/nix-index/files \
  https://github.com/Mic92/nix-index-database/releases/latest/download/index-x86_64-darwin

# for linux (x86_64-linux)
curl -L -o ~/.cache/nix-index/files \
  https://github.com/Mic92/nix-index-database/releases/latest/download/index-x86_64-linux
```

### setup (build from source)

this indexes all of nixpkgs locally. it's thorough but slow (~30+ minutes):

```bash
nix run 'nixpkgs#nix-index'
```

### updating the database

re-run either method above periodically to pick up new packages. the prebuilt database is rebuilt weekly. to check which nixpkgs commit a prebuilt release was built against, inspect the [flake.lock](https://github.com/Mic92/nix-index-database/blob/main/flake.lock) in the nix-index-database repo.

## available configurations

- `personal-laptop` (aarch64-darwin) - personal macbook
- `nixos-workstation` (x86_64-linux) - nixos workstation

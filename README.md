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

## available configurations

- `personal-laptop` (aarch64-darwin) - personal macbook
- `nixos-workstation` (x86_64-linux) - nixos workstation

# home-manager configuration

personal nix home-manager configuration for managing development environments across machines.

## repository organization

* `flake.nix`: entry point defining available configurations and exported modules
* `profiles/`: reusable configuration building blocks
  * `base.nix`: common packages and settings for all systems
  * `mac.nix`: macos-specific configuration
  * `linux.nix`: linux-specific configuration
* `hosts/`: per-machine configurations
  * `personal-laptop.nix`: example macos configuration
* `modules/`: program-specific configurations (zsh, kitty, fzf)
* `utils/`: bash scripts and helper functions

## installation

1. install nix: https://nixos.org/download/

2. clone this repository:
```bash
git clone https://github.com/rvadaga/home-manager ~/.config/home-manager
cd ~/.config/home-manager
```

3. activate the configuration:
```bash
nix run home-manager/release-25.05 -- switch --flake ".#personal-laptop"
```

## usage

### rebuild configuration
```bash
home-manager switch --flake ".#personal-laptop"
```

### update dependencies
```bash
nix flake update
```

### add a new host
copy `hosts/personal-laptop.nix` and customize the imports and settings for your machine.

## exported modules

this flake exports reusable modules that other configurations can import:

* `homeManagerModules.base` - common packages and settings
* `homeManagerModules.mac` - macos-specific configuration
* `homeManagerModules.linux` - linux-specific configuration

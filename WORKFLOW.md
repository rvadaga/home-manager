# home-manager workflow

this is the personal config repository that contains shared modules used by multiple configurations.

## repository structure

- `os-configs/base.nix` - base profile with core packages and settings
- `os-configs/mac.nix` - macos-specific configuration
- `os-configs/linux.nix` - linux-specific configuration
- `programs/` - individual feature modules (neovim, zsh, fzf, etc.)

## exported modules

this flake exports modules that can be imported by other flakes:

```nix
homeManagerModules = {
  base = ./os-configs/base.nix;
  mac = ./os-configs/mac.nix;
  linux = ./os-configs/linux.nix;
};
```

## workflow for updating shared config

when you make changes to shared modules (base.nix, programs/*, etc.):

1. make changes in this repo
2. commit and push to main
3. other flakes that import this config can update their lock file:
   ```bash
   nix flake update personal-config
   home-manager switch --flake ".#<config-name>"
   ```
